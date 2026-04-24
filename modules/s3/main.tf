data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────
# Company S3 Bucket
# ─────────────────────────────────────────
resource "aws_s3_bucket" "company" {
  bucket = "${var.project_name}-${var.environment}-company-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-${var.environment}-company"
  }
}

resource "aws_s3_bucket_versioning" "company" {
  bucket = aws_s3_bucket.company.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "company" {
  bucket = aws_s3_bucket.company.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "company" {
  bucket                  = aws_s3_bucket.company.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "company" {
  bucket = aws_s3_bucket.company.id

  rule {
    id     = "uploads-transition"
    status = "Enabled"
    filter { prefix = "uploads/" }
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "reports-expiry"
    status = "Enabled"
    filter { prefix = "reports/" }
    expiration { days = 365 }
  }
}

# ─────────────────────────────────────────
# IAM Policy – Backend (uploads r/w, documents+reports r)
# ─────────────────────────────────────────
resource "aws_iam_policy" "backend_s3" {
  name        = "${var.project_name}-${var.environment}-backend-s3-policy"
  description = "Backend server S3 access: uploads rw, documents and reports read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = aws_s3_bucket.company.arn
        Condition = {
          StringLike = { "s3:prefix" = ["uploads/*", "documents/*", "reports/*"] }
        }
      },
      {
        Sid    = "UploadsReadWrite"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.company.arn}/uploads/*"
      },
      {
        Sid    = "DocumentsReadOnly"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "${aws_s3_bucket.company.arn}/documents/*",
          "${aws_s3_bucket.company.arn}/reports/*"
        ]
      }
    ]
  })
}

# ─────────────────────────────────────────
# IAM Policy – Read Only (documents + reports)
# ─────────────────────────────────────────
resource "aws_iam_policy" "readonly_s3" {
  name        = "${var.project_name}-${var.environment}-readonly-s3-policy"
  description = "Read-only S3 access to documents and reports folders"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = aws_s3_bucket.company.arn
        Condition = {
          StringLike = { "s3:prefix" = ["documents/*", "reports/*"] }
        }
      },
      {
        Sid    = "ReadObjects"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "${aws_s3_bucket.company.arn}/documents/*",
          "${aws_s3_bucket.company.arn}/reports/*"
        ]
      }
    ]
  })
}

# ─────────────────────────────────────────
# Attach backend S3 policy to backend IAM role
# ─────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "backend_s3" {
  role       = var.backend_role_name
  policy_arn = aws_iam_policy.backend_s3.arn
}
