resource "aws_ecr_repository" "ecr_repo" {
  for_each = toset([
    "floodetl-transform",
    "floodetl-forecast"
  ])
  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "retain_recent" {
  for_each   = aws_ecr_repository.ecr_repo
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain the five newest images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_ecr" {
  name = "publish-project-images"
  role = aws_iam_role.github["deploy"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AuthenticateToEcr"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "PublishProjectImages"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]
        Resource = [
          for repository in aws_ecr_repository.ecr_repo :
          repository.arn
        ]
      }
    ]
  })
}

output "transform_repository_url" {
  description = "ECR repository URL for the transform image."
  value       = aws_ecr_repository.ecr_repo["floodetl-transform"].repository_url
}

output "forecast_repository_url" {
  description = "ECR repository URL for the forecast image."
  value       = aws_ecr_repository.ecr_repo["floodetl-forecast"].repository_url
}