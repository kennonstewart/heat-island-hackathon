variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile Terraform should use."
  type        = string
  default     = "default"
}

variable "environment" {
  description = "Environment label (single stack for hackathon use)."
  type        = string
  default     = "hackathon"
}

variable "name_prefix" {
  description = "Prefix used in resource names."
  type        = string
  default     = "heat-island"
}

variable "vpc_id" {
  description = "Optional VPC ID override. Leave null to use default VPC."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Optional subnet IDs override. Leave empty to use default VPC subnets."
  type        = list(string)
  default     = []
}

variable "api_allowed_cidrs" {
  description = "CIDR blocks allowed to access the API container port."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "api_container_image" {
  description = "Container image for the ECS API service."
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:stable"
}

variable "api_container_port" {
  description = "Port exposed by the API container."
  type        = number
  default     = 8080
}

variable "api_cpu" {
  description = "API task CPU units."
  type        = number
  default     = 512
}

variable "api_memory" {
  description = "API task memory in MiB."
  type        = number
  default     = 1024
}

variable "api_desired_count" {
  description = "Number of API tasks to run."
  type        = number
  default     = 1
}

variable "batch_container_image" {
  description = "Container image for AWS Batch jobs."
  type        = string
  default     = "public.ecr.aws/docker/library/python:3.11-slim"
}

variable "batch_max_vcpus" {
  description = "Maximum vCPUs for the Batch compute environment."
  type        = number
  default     = 32
}

variable "batch_job_vcpu" {
  description = "vCPU requested per Batch job."
  type        = number
  default     = 1
}

variable "batch_job_memory" {
  description = "Memory (MiB) requested per Batch job."
  type        = number
  default     = 2048
}

variable "data_bucket_name" {
  description = "Optional explicit data bucket name. Leave null to auto-generate."
  type        = string
  default     = null
}

variable "athena_results_prefix" {
  description = "Prefix in the data bucket for Athena query output."
  type        = string
  default     = "athena/results/"
}

variable "glue_database_name" {
  description = "Glue catalog database name."
  type        = string
  default     = "thermalgen"
}

variable "glue_crawler_name" {
  description = "Glue crawler name."
  type        = string
  default     = "thermalgen-curated-crawler"
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default = {
    owner = "group-1"
  }
}
