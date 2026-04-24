variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "eks_node_security_group_id" {
  type        = string
  description = "Security group ID of the EKS node group – used to allow RDS ingress"
}

variable "eks_cluster_name" {
  type = string
}

variable "db_name" {
  type    = string
  default = "ekscorp"
}

variable "db_username" {
  type    = string
  default = "ekscorp_admin"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.medium"
}
