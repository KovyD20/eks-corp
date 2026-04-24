variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "backend_role_name" {
  type        = string
  description = "IAM role name of the backend pods – the backend S3 policy will be attached to this role"
}
