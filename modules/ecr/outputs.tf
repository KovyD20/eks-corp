output "repository_urls" {
  description = "Map of repository name to URL"
  value = {
    for name, repo in aws_ecr_repository.repos :
    name => repo.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository name to ARN"
  value = {
    for name, repo in aws_ecr_repository.repos :
    name => repo.arn
  }
}

output "registry_id" {
  description = "The AWS account ID associated with the ECR registry"
  value       = data.aws_caller_identity.current.account_id
}