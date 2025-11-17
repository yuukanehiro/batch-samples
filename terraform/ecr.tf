# ECR Repository for Sample Batch
resource "aws_ecr_repository" "sample_batch" {
  name                 = "${var.project_name}-${var.environment}/sample-batch"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sample-batch"
  }
}

# ECR Repository for Retry Failed Tenants
resource "aws_ecr_repository" "retry_batch" {
  name                 = "${var.project_name}-${var.environment}/retry-failed-tenants"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-retry-batch"
  }
}

# ECR Repository for Run Specific Tenants
resource "aws_ecr_repository" "specific_batch" {
  name                 = "${var.project_name}-${var.environment}/run-specific-tenants"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-specific-batch"
  }
}

# Lifecycle Policy for ECR (古いイメージの自動削除)
resource "aws_ecr_lifecycle_policy" "sample_batch" {
  repository = aws_ecr_repository.sample_batch.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "retry_batch" {
  repository = aws_ecr_repository.retry_batch.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "specific_batch" {
  repository = aws_ecr_repository.specific_batch.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
