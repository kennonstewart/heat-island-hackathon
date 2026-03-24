output "aws_region" {
  value       = var.aws_region
  description = "AWS region used by this stack."
}

output "data_bucket_name" {
  value       = aws_s3_bucket.data.bucket
  description = "S3 bucket for raw/curated/features/artifacts data."
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
  description = "ECS cluster name for the API service."
}

output "ecs_service_name" {
  value       = aws_ecs_service.api.name
  description = "ECS service name for the API."
}

output "batch_job_queue_arn" {
  value       = aws_batch_job_queue.main.arn
  description = "AWS Batch queue ARN for offline jobs."
}

output "batch_job_definition_arn" {
  value       = aws_batch_job_definition.offline.arn
  description = "Default Batch job definition ARN."
}

output "glue_database_name" {
  value       = aws_glue_catalog_database.thermalgen.name
  description = "Glue catalog database name."
}

output "glue_crawler_name" {
  value       = aws_glue_crawler.curated.name
  description = "Glue crawler over curated S3 data."
}

output "athena_workgroup" {
  value       = aws_athena_workgroup.main.name
  description = "Athena workgroup configured for the data bucket."
}
