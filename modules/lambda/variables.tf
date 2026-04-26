variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "s3_bucket_name" {
  type        = string
  description = "Company S3 bucket name – Lambda reads metadata and writes reports here"
}

variable "health_endpoint" {
  type        = string
  description = "ALB hostname for the backend health check (no protocol prefix)"
}
