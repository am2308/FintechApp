# ECR Repositories
resource "aws_ecr_repository" "account_service" {
  name                 = "account-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "transaction_service" {
  name                 = "transaction-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "auth_service" {
  name                 = "auth-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each = {
    account_service     = aws_ecr_repository.account_service.name
    transaction_service = aws_ecr_repository.transaction_service.name
    auth_service        = aws_ecr_repository.auth_service.name
  }

  repository = each.value

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }

      action = {
        type = "expire"
      }
    }]
  })
}

# ECR API VPC Interface Endpoint
resource "aws_vpc_endpoint" "ecr_api_endpoint" {
  vpc_id             = var.production_vpc_id
  service_name       = "com.amazonaws.eu-west-2.ecr.api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.production_private_subnet_ids
  security_group_ids = [aws_security_group.interface_endpoints_sg[0].id]
}

# ECR DKR VPC Interface Endpoint
resource "aws_vpc_endpoint" "ecr_dkr_endpoint" {
  vpc_id             = var.production_vpc_id
  service_name       = "com.amazonaws.eu-west-2.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.production_private_subnet_ids
  security_group_ids = [aws_security_group.interface_endpoints_sg[0].id]
}

# Security Group for Interface Endpoints
resource "aws_security_group" "interface_endpoints_sg" {
  count  = var.vpc_name == "production" ? 1 : 0
  name   = "${var.vpc_name}-interface-endpoint-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-ecr-interface-endpoint-sg"
  })
}

# Interface Endpoints
resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each = var.vpc_name == "production" ? toset([
    "ecr"
  ]) : []

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.production_private_subnet_ids
  security_group_ids  = [aws_security_group.interface_endpoints_sg[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.vpc_name}-${each.value}-endpoint"
  })
}
