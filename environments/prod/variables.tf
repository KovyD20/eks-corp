variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "eks-corp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "health_endpoint" {
  description = "ALB hostname of the backend Ingress, checked by the service check Lambda"
  type        = string
}