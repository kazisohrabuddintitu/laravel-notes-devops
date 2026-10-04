# Security groups form a chain: internet → ALB (80) → app (8080) → database (5432).
# Each group only accepts traffic from the group before it.
#
# Rules are separate resources (aws_vpc_security_group_*_rule) instead of inline
# blocks: each rule can be changed on its own, and groups can reference each other.
# Terraform removes the default "allow all outbound" rule from every group it
# creates, so outbound traffic is only what is listed here.

resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB - HTTP from the internet"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project}-alb-sg"
  }
}

resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "App containers - 8080 from the ALB only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project}-app-sg"
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project}-db-sg"
  description = "RDS Postgres - 5432 from the app only"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project}-db-sg"
  }
}

# --- ALB ---

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests to the app containers"
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.app.id
}

# --- App ---

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP from the ALB"
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
  referenced_security_group_id = aws_security_group.alb.id
}

# The app needs outbound access: ECR (image pull), CloudWatch Logs, RDS and,
# later, external APIs. Without a NAT gateway this goes through the internet gateway.
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Database ---

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "Postgres from the app"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app.id
}

# No egress rule for the database: it only answers connections (allowed
# automatically, security groups are stateful) and never starts its own.
