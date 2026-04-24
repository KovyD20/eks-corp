output "db_endpoint" {
  description = "RDS instance hostname"
  value       = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret holding DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.db_credentials.name
}

output "backend_role_arn" {
  description = "IAM role ARN for backend Pod Identity"
  value       = aws_iam_role.backend.arn
}
