

locals {
  name = "${var.project_name}-${var.environment}"
  azs  = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
}

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = local.azs

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

  enable_nat_gateway = true
}

# ─────────────────────────────────────────
# ECR
# ─────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  repositories = [
    "backend",    
    "frontend"
  ]

  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true
  max_image_count      = 10
}

# ─────────────────────────────────────────
# EKS
# ─────────────────────────────────────────

module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  kubernetes_version  = "1.29"
  node_instance_types = ["t3.large"]

  node_desired_size = 2
  node_min_size     = 2
  node_max_size     = 6
  node_disk_size    = 50
}