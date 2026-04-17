

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