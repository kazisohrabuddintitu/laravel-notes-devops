# Application Load Balancer in the public subnets: listens on HTTP 80 and
# forwards to the app tasks (target type "ip", because Fargate tasks have
# their own network interface). HTTPS on 443 comes with the custom domain.

resource "aws_lb" "app" {
  name               = "${var.project}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project}-tg"
  target_type = "ip"
  protocol    = "HTTP"
  port        = 8080
  vpc_id      = aws_vpc.main.id

  # Wait 30 seconds (default 300) for in-flight requests before a stopped
  # task is removed, so deploys and teardowns are quicker.
  deregistration_delay = 30

  health_check {
    path                = "/up"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  protocol          = "HTTP"
  port              = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
