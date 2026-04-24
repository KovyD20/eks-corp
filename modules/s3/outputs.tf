output "bucket_name" {
  value = aws_s3_bucket.company.id
}

output "bucket_arn" {
  value = aws_s3_bucket.company.arn
}

output "backend_s3_policy_arn" {
  value = aws_iam_policy.backend_s3.arn
}

output "readonly_s3_policy_arn" {
  value = aws_iam_policy.readonly_s3.arn
}
