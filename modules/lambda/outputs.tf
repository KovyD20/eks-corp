output "function_name" {
  value = aws_lambda_function.service_check.function_name
}

output "function_arn" {
  value = aws_lambda_function.service_check.arn
}

output "policy_arn" {
  value = aws_iam_policy.service_check.arn
}
