locals {
  resolved_vpc_id     = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
  resolved_subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.default[0].ids

  data_bucket_name = coalesce(
    var.data_bucket_name,
    "${var.name_prefix}-${var.environment}-${data.aws_caller_identity.current.account_id}-data"
  )

  common_name = "${var.name_prefix}-${var.environment}"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "default" {
  count   = var.vpc_id == null ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = length(var.subnet_ids) == 0 ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.resolved_vpc_id]
  }
}

resource "aws_s3_bucket" "data" {
  bucket        = local.data_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "prefixes" {
  for_each = toset([
    "raw/",
    "raw/source=unknown/dataset=unknown/ingest_date=1970-01-01/",
    "curated/",
    "curated/domain=thermal/dataset=unknown/year=1970/month=01/day=01/",
    "features/",
    "features/model=thermalgen/version=v0/run_date=1970-01-01/",
    "inference/",
    "inference/run_id=sample/date=1970-01-01/",
    "artifacts/",
    "artifacts/models/",
    var.athena_results_prefix
  ])

  bucket  = aws_s3_bucket.data.id
  key     = each.value
  content = ""
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.common_name}-api"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "batch" {
  name              = "/aws/batch/job/${local.common_name}"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "main" {
  name = "${local.common_name}-cluster"
}

resource "aws_security_group" "app" {
  name        = "${local.common_name}-app-sg"
  description = "Access for ECS API and Batch Fargate tasks"
  vpc_id      = local.resolved_vpc_id

  ingress {
    from_port   = var.api_container_port
    to_port     = var.api_container_port
    protocol    = "tcp"
    cidr_blocks = var.api_allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.common_name}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "${local.common_name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy" "ecs_data_access" {
  name = "${local.common_name}-data-access"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.data.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.data.arn}/*"
      }
    ]
  })
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${local.common_name}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.api_cpu)
  memory                   = tostring(var.api_memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = var.api_container_image
      essential = true
      portMappings = [
        {
          containerPort = var.api_container_port
          hostPort      = var.api_container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DATA_BUCKET"
          value = aws_s3_bucket.data.bucket
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "api" {
  name            = "${local.common_name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.resolved_subnet_ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }
}

data "aws_iam_policy_document" "batch_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["batch.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "batch_service" {
  name               = "${local.common_name}-batch-service"
  assume_role_policy = data.aws_iam_policy_document.batch_assume.json
}

resource "aws_iam_role_policy_attachment" "batch_service_managed" {
  role       = aws_iam_role.batch_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_batch_compute_environment" "fargate" {
  compute_environment_name = "${local.common_name}-batch-ce"
  service_role             = aws_iam_role.batch_service.arn
  type                     = "MANAGED"
  state                    = "ENABLED"

  compute_resources {
    type               = "FARGATE"
    max_vcpus          = var.batch_max_vcpus
    subnets            = local.resolved_subnet_ids
    security_group_ids = [aws_security_group.app.id]
  }

  depends_on = [aws_iam_role_policy_attachment.batch_service_managed]
}

resource "aws_batch_job_queue" "main" {
  name     = "${local.common_name}-job-queue"
  state    = "ENABLED"
  priority = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.fargate.arn
  }
}

resource "aws_batch_job_definition" "offline" {
  name                  = "${local.common_name}-offline-job"
  type                  = "container"
  platform_capabilities = ["FARGATE"]
  propagate_tags        = true

  container_properties = jsonencode({
    image            = var.batch_container_image
    executionRoleArn = aws_iam_role.ecs_task_execution.arn
    jobRoleArn       = aws_iam_role.ecs_task.arn
    command          = ["python", "-c", "print('batch job started')"]
    networkConfiguration = {
      assignPublicIp = "ENABLED"
    }
    resourceRequirements = [
      {
        type  = "VCPU"
        value = tostring(var.batch_job_vcpu)
      },
      {
        type  = "MEMORY"
        value = tostring(var.batch_job_memory)
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.batch.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "batch"
      }
    }
  })
}

data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_crawler" {
  name               = "${local.common_name}-glue-crawler"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${local.common_name}-glue-s3-access"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.data.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.data.arn}/*"
      }
    ]
  })
}

resource "aws_glue_catalog_database" "thermalgen" {
  name = var.glue_database_name
}

resource "aws_glue_crawler" "curated" {
  name          = var.glue_crawler_name
  database_name = aws_glue_catalog_database.thermalgen.name
  role          = aws_iam_role.glue_crawler.arn
  table_prefix  = "thermalgen_"

  s3_target {
    path = "s3://${aws_s3_bucket.data.bucket}/curated/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  depends_on = [
    aws_iam_role_policy_attachment.glue_service_role,
    aws_iam_role_policy.glue_s3_access
  ]
}

resource "aws_athena_workgroup" "main" {
  name = "${local.common_name}-athena"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.data.bucket}/${var.athena_results_prefix}"
    }
  }
}
