output "deploy_role_arn" {
  description = "IAM role for the GitHub Actions deploy job (save as the AWS_DEPLOY_ROLE_ARN Environment variable)"
  value       = aws_iam_role.github_deploy.arn
}
