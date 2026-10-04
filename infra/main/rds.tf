# PostgreSQL in the private subnets, reachable only from the app security group.
#
# The master password is managed by RDS itself (manage_master_user_password):
# RDS generates it and stores it in AWS Secrets Manager. Terraform never sees
# the value, so it is not in the code, the plan or the state. ECS reads it from
# the secret when a container starts.

resource "aws_db_subnet_group" "main" {
  name        = "${var.project}-db-subnets"
  description = "Private subnets for the ${var.project} database"
  subnet_ids  = aws_subnet.private[*].id
}

resource "aws_db_instance" "main" {
  identifier = "${var.project}-db"

  engine         = "postgres"
  engine_version = "18"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "notes"
  username                    = "notes"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 1
  copy_tags_to_snapshot   = true

  # Learning setup: `terraform destroy` removes the database without a final
  # snapshot. Production would keep a final snapshot and deletion protection.
  skip_final_snapshot      = true
  delete_automated_backups = true
  deletion_protection      = false
  apply_immediately        = true
}
