# ─────────────────────────────────────────
# IAM Role for backend Pod Identity
# ─────────────────────────────────────────
resource "aws_iam_role" "backend" {
  name = "${local.name}-backend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "pods.eks.amazonaws.com" }
        Action    = ["sts:AssumeRole", "sts:TagSession"]
      }
    ]
  })

  tags = {
    Name = "${local.name}-backend-role"
  }
}

resource "aws_iam_role_policy_attachment" "backend_secrets" {
  role       = aws_iam_role.backend.name
  policy_arn = module.rds.secrets_read_policy_arn
}

resource "aws_iam_role_policy_attachment" "backend_s3" {
  role       = aws_iam_role.backend.name
  policy_arn = module.s3.backend_s3_policy_arn
}

# ─────────────────────────────────────────
# Pod Identity Association – backend SA → IAM role
# ─────────────────────────────────────────
resource "aws_eks_pod_identity_association" "backend" {
  cluster_name    = module.eks.cluster_name
  namespace       = "backend"
  service_account = "backend-sa"
  role_arn        = aws_iam_role.backend.arn
}
