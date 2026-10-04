output "app_url" {
  description = "Public URL of the app (HTTP until a domain and certificate are added)"
  value       = "http://${aws_lb.app.dns_name}"
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB, Fargate tasks)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (RDS)"
  value       = aws_subnet.private[*].id
}

output "ecr_repository_url" {
  description = "URL to tag and push the app image to"
  value       = aws_ecr_repository.app.repository_url
}

output "db_endpoint" {
  description = "Hostname of the PostgreSQL database"
  value       = aws_db_instance.main.address
}

output "app_key_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the Laravel APP_KEY"
  value       = aws_secretsmanager_secret.app_key.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "task_definition_arn" {
  description = "ARN of the current app task definition revision"
  value       = aws_ecs_task_definition.app.arn
}

output "app_security_group_id" {
  description = "Security group for app tasks (also used for one-off tasks such as migrations)"
  value       = aws_security_group.app.id
}

output "db_master_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the database credentials"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}
