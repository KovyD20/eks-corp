output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS PostgreSQL hostname (private)"
  value       = module.rds.db_endpoint
}

output "rds_db_name" {
  value = module.rds.db_name
}

output "rds_secret_arn" {
  description = "Secrets Manager secret ARN for DB credentials"
  value       = module.rds.secret_arn
}

output "backend_role_arn" {
  description = "IAM role ARN used by backend pods via Pod Identity"
  value       = module.rds.backend_role_arn
}

output "s3_bucket_name" {
  description = "Company S3 bucket name"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  value = module.s3.bucket_arn
}
