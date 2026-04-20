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
  description = "Private subnets for EKS nodes (multi-AZ)"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets for Load Balancers"
  type        = list(string)
}

variable "kubernetes_version" {
  type    = string
  default = "1.29"
}

variable "node_instance_types" {
  description = "EC2 instance types for node group"
  type        = list(string)
  default     = ["t3.large"]  
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2 
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "node_disk_size" {
  description = "Node disk size in GB"
  type        = number
  default     = 50
}