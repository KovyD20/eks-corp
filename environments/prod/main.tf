data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
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

  kubernetes_version  = "1.35"
  node_instance_types = ["t3.large"]

  node_desired_size = 2
  node_min_size     = 2
  node_max_size     = 6
  node_disk_size    = 50
}

# ─────────────────────────────────────────
# Lambda – Service Check Automation
# ─────────────────────────────────────────
module "lambda" {
  source = "../../modules/lambda"

  project_name    = var.project_name
  environment     = var.environment
  s3_bucket_name  = module.s3.bucket_name
  health_endpoint = var.health_endpoint
}

# ─────────────────────────────────────────
# Company S3
# ─────────────────────────────────────────
module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

# ─────────────────────────────────────────
# RDS
# ─────────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  eks_cluster_security_group_id = module.eks.cluster_security_group_id

  db_instance_class = "db.t3.medium"
  db_name           = "ekscorp"
  db_username       = "ekscorp_admin"
}