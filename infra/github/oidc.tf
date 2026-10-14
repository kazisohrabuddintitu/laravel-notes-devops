# GitHub Actions -> AWS without stored keys.
#
# The OIDC provider tells IAM to trust tokens signed by GitHub. The deploy role
# accepts only tokens issued to jobs of one repository that run in the
# production Environment, and gets short-lived credentials (1 hour) for them.
#
# The app resources live in infra/main and are often destroyed, so their ARNs
# are built from their names here instead of being read from that state.

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  arn_prefix = "arn:aws:%s:${var.aws_region}:${local.account_id}"

  cluster_name        = "${var.project}-cluster"
  service_name        = "${var.project}-web"
  task_family         = var.project
  ecr_repository      = var.project
  task_execution_role = "${var.project}-task-execution"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# --- Who may assume the role ---

data "aws_iam_policy_document" "github_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # The token must be meant for AWS STS...
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # ...and come from a job in this repo that uses the production Environment.
    # Which branches may use that Environment is set in GitHub (main only).
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "${var.project}-github-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

# --- What the role may do: push one image repo, deploy one service ---

data "aws_iam_policy_document" "github_deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPushApp"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = ["${format(local.arn_prefix, "ecr")}:repository/${local.ecr_repository}"]
  }

  # These two actions do not support resource-level permissions.
  statement {
    sid       = "TaskDefinitions"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid       = "TagNewTaskDefinitions"
    actions   = ["ecs:TagResource"]
    resources = ["${format(local.arn_prefix, "ecs")}:task-definition/${local.task_family}:*"]

    condition {
      test     = "StringEquals"
      variable = "ecs:CreateAction"
      values   = ["RegisterTaskDefinition"]
    }
  }

  # One-off migration task, only in our cluster.
  statement {
    sid       = "RunMigrations"
    actions   = ["ecs:RunTask"]
    resources = ["${format(local.arn_prefix, "ecs")}:task-definition/${local.task_family}:*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = ["${format(local.arn_prefix, "ecs")}:cluster/${local.cluster_name}"]
    }
  }

  statement {
    sid       = "WatchTasks"
    actions   = ["ecs:DescribeTasks"]
    resources = ["${format(local.arn_prefix, "ecs")}:task/${local.cluster_name}/*"]
  }

  statement {
    sid       = "DeployService"
    actions   = ["ecs:DescribeServices", "ecs:UpdateService"]
    resources = ["${format(local.arn_prefix, "ecs")}:service/${local.cluster_name}/${local.service_name}"]
  }

  # ECS needs this to start tasks that use the execution role. Without the
  # condition the role could be handed to any service.
  statement {
    sid       = "PassTaskExecutionRole"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.task_execution_role}"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy-notes-app"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
