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

output "secrets_read_policy_arn" {
  description = "IAM policy ARN that allows reading the DB credentials secret"
  value       = aws_iam_policy.backend_secrets.arn
}
