data "archive_file" "service_check" {
  type        = "zip"
  source_file = "${path.root}/../../lambda/service_check/index.js"
  output_path = "${path.root}/../../lambda/service_check/service_check.zip"
}

# ─────────────────────────────────────────
# IAM Role for Lambda
# ─────────────────────────────────────────
resource "aws_iam_role" "service_check" {
  name = "${var.project_name}-${var.environment}-service-check-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ─────────────────────────────────────────
# Dedicated policy for the service check Lambda
# ─────────────────────────────────────────
resource "aws_iam_policy" "service_check" {
  name        = "${var.project_name}-${var.environment}-service-check-policy"
  description = "Allows the service check Lambda to write logs, read S3, and save reports"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid    = "S3List"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}"
      },
      {
        Sid    = "S3ReadAll"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/*"
      },
      {
        Sid    = "S3WriteReports"
        Effect = "Allow"
        Action = ["s3:PutObject"]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/reports/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "service_check" {
  role       = aws_iam_role.service_check.name
  policy_arn = aws_iam_policy.service_check.arn
}

# ─────────────────────────────────────────
# Lambda Function
# ─────────────────────────────────────────
resource "aws_lambda_function" "service_check" {
  function_name    = "${var.project_name}-${var.environment}-service-check"
  role             = aws_iam_role.service_check.arn
  filename         = data.archive_file.service_check.output_path
  source_code_hash = data.archive_file.service_check.output_base64sha256
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  timeout          = 30

  environment {
    variables = {
      HEALTH_ENDPOINT = var.health_endpoint
      S3_BUCKET       = var.s3_bucket_name
    }
  }
}

# ─────────────────────────────────────────
# EventBridge – run every hour
# ─────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "service_check" {
  name                = "${var.project_name}-${var.environment}-service-check-schedule"
  description         = "Trigger service check Lambda every hour"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "service_check" {
  rule      = aws_cloudwatch_event_rule.service_check.name
  target_id = "ServiceCheckLambda"
  arn       = aws_lambda_function.service_check.arn
}

resource "aws_lambda_permission" "service_check" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.service_check.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.service_check.arn
}
