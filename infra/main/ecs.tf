# ECS: the cluster, the task execution role, the log group, the task
# definition (the "recipe" for the app container) and the service that keeps
# the tasks running behind the load balancer.

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7
}

# --- Task execution role: used by ECS (not by the app) to pull the image,
# write logs and read the secrets injected into the container. ---

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.project}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_app_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_db_instance.main.master_user_secret[0].secret_arn,
      aws_secretsmanager_secret.app_key.arn,
    ]
  }
}

resource "aws_iam_role_policy" "read_app_secrets" {
  name   = "read-app-secrets"
  role   = aws_iam_role.task_execution.id
  policy = data.aws_iam_policy_document.read_app_secrets.json
}

# --- Task definition ---

resource "aws_ecs_task_definition" "app" {
  family                   = var.project
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
    essential = true

    portMappings = [{
      name          = "http"
      containerPort = 8080
      protocol      = "tcp"
    }]

    environment = [
      { name = "APP_ENV", value = "production" },
      { name = "APP_DEBUG", value = "false" },
      { name = "LOG_CHANNEL", value = "stderr" },
      { name = "DB_CONNECTION", value = "pgsql" },
      { name = "DB_HOST", value = aws_db_instance.main.address },
      { name = "DB_PORT", value = tostring(aws_db_instance.main.port) },
      { name = "DB_DATABASE", value = aws_db_instance.main.db_name },
      { name = "DB_USERNAME", value = aws_db_instance.main.username },
      { name = "DB_SSLMODE", value = "require" },
    ]

    # Values are read from Secrets Manager when the container starts; only
    # the references are stored here.
    secrets = [
      { name = "APP_KEY", valueFrom = aws_secretsmanager_secret.app_key.arn },
      { name = "DB_PASSWORD", valueFrom = "${aws_db_instance.main.master_user_secret[0].secret_arn}:password::" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "app"
      }
    }
  }])
}

# --- Service: keeps desired_count tasks running and registers them in the
# target group. Run migrations (one-off task) before changing the image. ---

resource "aws_ecs_service" "app" {
  name            = "${var.project}-web"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Without a NAT gateway, tasks need a public IP to reach ECR and CloudWatch.
  # Inbound traffic is still limited to the ALB by the app security group.
  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 8080
  }

  health_check_grace_period_seconds = 60

  # Start new tasks before stopping old ones (zero downtime), and roll back
  # automatically when a new deployment keeps failing.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  propagate_tags = "SERVICE"

  # The target group must be attached to the ALB before the service can use it.
  depends_on = [aws_lb_listener.http]
}
