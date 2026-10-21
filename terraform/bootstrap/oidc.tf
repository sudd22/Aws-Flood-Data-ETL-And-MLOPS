data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

locals {
  github_subject_prefix = "repo:sudd22@219440021/Aws-Flood-Data-ETL-And-MLOPS@1414384299"

  github_role_subjects = {
    ci = [
      "${local.github_subject_prefix}:pull_request",
      "${local.github_subject_prefix}:ref:refs/heads/main"
    ]
    deploy = [
      "${local.github_subject_prefix}:ref:refs/heads/main"
    ]
  }
}

resource "aws_iam_role" "github" {
  for_each    = local.github_role_subjects
  name        = "floodetl-github-${each.key}"
  description = "GitHub Actions ${each.key} role for the flood ETL project."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = each.value
          }
        }
      }
    ]
  })
}

locals {
  main_state_key = "main/terraform.tfstate"
}

resource "aws_iam_role_policy" "github_state" {
  for_each = aws_iam_role.github

  name = "terraform-main-state"
  role = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListStateBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Sid    = "AccessMainState"
        Effect = "Allow"
        Action = each.key == "deploy" ? [
          "s3:GetObject",
          "s3:PutObject"
        ] : ["s3:GetObject"]
        Resource = "${aws_s3_bucket.terraform_state.arn}/${local.main_state_key}"
      },
      {
        Sid    = "ManageMainStateLock"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/${local.main_state_key}.tflock"
      }
    ]
  })
}

output "ci_role_arn" {
  description = "GitHub Actions CI role ARN."
  value       = aws_iam_role.github["ci"].arn
}

output "deploy_role_arn" {
  description = "GitHub Actions deploy role ARN."
  value       = aws_iam_role.github["deploy"].arn
}