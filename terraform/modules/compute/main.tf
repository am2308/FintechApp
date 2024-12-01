data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Lambda Security Group
resource "aws_security_group" "lambda" {
  name        = "lambda-sg"
  description = "Security Group for Fraud Detection Lambda"
  vpc_id      = var.production_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "Lambda Security Group"
  })
}

# Bastion Hosts ASG in Management VPC
resource "aws_autoscaling_group" "bastion" {
  name                = "bastion-asg"
  vpc_zone_identifier = var.management_public_subnet_ids
  target_group_arns   = [aws_lb_target_group.bastion.arn]
  health_check_type   = "ELB"
  min_size            = 1
  max_size            = 2
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.bastion.id
    version = "$Latest"
  }
}

# Bastion Launch Template
resource "aws_launch_template" "bastion" {
  name_prefix   = "bastion"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.bastion.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.bastion.name
  }

  user_data = base64encode(<<-EOF
                #!/bin/bash
                yum install -y postgresql-client mysql-client
                yum update -y
                EOF
  )
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "bastion" {
  name = "bastion-profile"
  role = var.bastion_instance_profile_role
}

# Target Group for Bastion Host
resource "aws_lb_target_group" "bastion" {
  name        = "bastion-tg"
  port        = 22
  protocol    = "TCP"
  vpc_id      = var.management_vpc_id
  target_type = "instance"
}

# Security Group for Bastion
resource "aws_security_group" "bastion" {
  name   = "bastion-sg"
  vpc_id = var.management_vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.255.0.0/16"] # random IP replicating corporate offices
  }
}

# ALB
resource "aws_lb" "production" {
  name               = "banking-prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.production_public_subnet_ids

  enable_deletion_protection = true
  enable_http2               = true
  drop_invalid_header_fields = true

  access_logs {
    bucket  = var.alb_bucket_id
    prefix  = "alb-logs"
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "Production VPC ALB"
  })

  depends_on = [
    var.alb_s3_bucket_policy
  ]
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.production.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "No routes matched"
      status_code  = "404"
    }
  }
}

# HTTP to HTTPS Redirect Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.production.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "banking-alb-sg"
  description = "Security Group for Banking ALB"
  vpc_id      = var.production_vpc_id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere (redirect)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Target Group for Account Service
resource "aws_lb_target_group" "account_service" {
  name        = "account-service-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.production_vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    timeout             = 5
    path                = "/health"
    matcher             = "200"
    unhealthy_threshold = 2
  }
}

# Target Group for Transaction Service
resource "aws_lb_target_group" "transaction_service" {
  name        = "transaction-service-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.production_vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    timeout             = 5
    path                = "/health"
    matcher             = "200"
    unhealthy_threshold = 2
  }
}

# Target Group for Auth Service
resource "aws_lb_target_group" "auth_service" {
  name        = "auth-service-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.production_vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    timeout             = 5
    path                = "/health"
    matcher             = "200"
    unhealthy_threshold = 2
  }
}

# Listener Rules
resource "aws_lb_listener_rule" "account_service" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.account_service.arn
  }

  condition {
    path_pattern {
      values = ["/account/*"]
    }
  }
}

resource "aws_lb_listener_rule" "transaction_service" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.transaction_service.arn
  }

  condition {
    path_pattern {
      values = ["/transaction/*"]
    }
  }
}

resource "aws_lb_listener_rule" "auth_service" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 120

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_service.arn
  }

  condition {
    path_pattern {
      values = ["/auth/*"]
    }
  }
}
