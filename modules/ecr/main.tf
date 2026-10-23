# ─────────────────────────────────────────
# ECR REPOSITORIES
# ─────────────────────────────────────────
resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repositories)

  name                 = "${var.project_name}-${var.environment}-${each.value}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  force_delete = true

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.value}"
  }
}

# ─────────────────────────────────────────
# LIFECYCLE POLICY
# ─────────────────────────────────────────
resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
