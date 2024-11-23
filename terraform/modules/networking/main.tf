# VPC
resource "aws_vpc" "main" {
    cidr_block = var.vpc_cidr
    tags = local.common_tags
    enable_dns_support = true
    enable_dns_hostnames = true
}

# Public Subnets
resource "aws_subnet" "public" {
    for_each = toset(var.public_subnets)
    vpc_id = aws_vpc.main.id
    cidr_block = each.value
    availability_zone = element(var.availability_zones, index(var.public_subnets, each.value))
    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-public-${each.key}"
    })
}

# Private Subnets
resource "aws_subnet" "private" {
    for_each = toset(var.private_subnets)
    vpc_id = aws_vpc.main.id
    cidr_block = each.value
    availability_zone = element(var.availability_zones, index(var.private_subnets, each.value))
    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-private-${each.key}"
    })
}

# IGW
resource "aws_internet_gateway" "igw" {
    count = var.enable_igw  ? 1 : 0
    vpc_id = aws_vpc.main.id
    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-igw"
    })
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
    for_each = var.vpc_name == "production" ? toset(var.public_subnets) : [] # Only for Production VPC
    allocation_id = aws_eip.nat[each.key].id
    subnet_id = aws_subnet.public[each.key].id
}

resource "aws_eip" "nat" {
    for_each = var.vpc_name == "production" ? toset(var.public_subnets) : [] # Only for Production VPC
}

# Public Route Tables (for Production, Management, Security VPCs)
resource "aws_route_table" "public" {
    for_each = toset(var.public_subnets)
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw[0].id
    }

    route {
        cidr_block = "10.0.0.0/8" # All VPC CIDR
        transit_gateway_id = var.transit_gateway_id
    }

    route {
        cidr_block = "172.16.0.0/12" # On-Prem CIDR
        transit_gateway_id = var.transit_gateway_id
    }

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-public-${each.key}"
    })
}

# NAT Gateway Route Tables (only for Production VPC)
resource "aws_route_table" "private_nat" {
    for_each = var.vpc_name == "production" ? toset(var.private_subnets) : []
    vpc_id = aws_vpc.main.id
    
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat[var.public_subnets[0]].id
    }

     route {
        cidr_block = "10.0.0.0/8" # All VPC CIDR
        transit_gateway_id = var.transit_gateway_id
    }

    route {
        cidr_block = "172.16.0.0/12" # On-Prem CIDR
        transit_gateway_id = var.transit_gateway_id
    }
    
    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-private-nat-${each.key}"
    })
}

# Data VPC Private Route Table (no internet)
resource "aws_route_table" "private_no_internet" {
    count = var.vpc_name == "data" ? 1 : 0
    vpc_id = aws_vpc.main.id

     route {
        cidr_block = "10.0.0.0/8" # All VPC CIDR
        transit_gateway_id = var.transit_gateway_id
    }

    route {
        cidr_block = "172.16.0.0/12" # On-Prem CIDR
        transit_gateway_id = var.transit_gateway_id
    }
    
    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-private-no-internet"
    })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
    for_each = aws_subnet.public
    subnet_id = each.value.id
    route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route_table_association" "private" {
    for_each = aws_subnet.private
    subnet_id = each.value.id
    route_table_id = var.vpc_name == "production" ? aws_route_table.private_nat[each.key].id : aws_route_table.private_no_internet[0].id
}

# Gateway Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
    count = var.vpc_name == "data" ? 1 : 0
    vpc_id = aws_vpc.main.id
    service_name = "com.amazonaws.${var.region}.s3"
    vpc_endpoint_type = "Gateway"

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-s3-endpoint"
    })
}

# Gateway Endpoint for DynamoDB
resource "aws_vpc_endpoint" "dynamodb" {
    count = var.vpc_name == "data" ? 1 : 0
    vpc_id = aws_vpc.main.id
    service_name = "com.amazonaws.${var.region}.dynamodb"
    vpc_endpoint_type = "Gateway"

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-dynamodb-endpoint"
    })
}


# Production VPC Security Groups
resource "aws_security_group" "prod_web" {
    count = var.vpc_name == "production" ? 1: 0
    name = "${var.vpc_name}-web-sg"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port= 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port= 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-web-sg"
    })
}

resource "aws_security_group" "prod_app" {
    count = var.vpc_name == "production" ? 1: 0
    name = "${var.vpc_name}-app-sg"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 8080 # App Port
        to_port = 8080
        protocol = "tcp"
        security_groups = [aws_security_group.prod_web[0].id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-app-sg"
    })
}

# Data VPC Security Groups
resource "aws_security_group" "data_db" {
    count = var.vpc_name == "data" ? 1: 0
    name = "${var.vpc_name}-db-sg"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        cidr_blocks = ["10.1.0.0/16"] # Production VPC CIDR
    }

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-db-sg"
    })
}

# Management VPC Security Groups
resource "aws_security_group" "mgmt_bastion" {
    count = var.vpc_name == "management" ? 1: 0
    name = "${var.vpc_name}-bastion-sg"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 22 
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["89.242.83.136/32"] # TRUSTED IP
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-bastion-sg"
    })
}

resource "aws_security_group" "mgmt_admin" {
    count = var.vpc_name == "management" ? 1: 0
    name = "${var.vpc_name}-admin-sg"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 22 
        to_port = 22
        protocol = "tcp"
        security_groups = [aws_security_group.mgmt_bastion[0].id]
    }

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-admin-sg"
    })
}

# Security VPC Security Groups
resource "aws_security_group" "sec_monitoring" {
    count = var.vpc_name == "security" ? 1 : 0
    name   = "${var.vpc_name}-monitoring-sg"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port   = 9090 # Prometheus
        to_port     = 9090
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
    }
    
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-monitoring-sg"
    })
}

resource "aws_security_group" "sec_logging" {
    count = var.vpc_name == "security" ? 1 : 0
    name   = "${var.vpc_name}-logging-sg"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port   = 514
        to_port     = 514
        protocol    = "udp"
        cidr_blocks = ["10.0.0.0/8"]
    }
    
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-logging-sg"
    })
}


# TGW VPC Attachments
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attachment" {
    transit_gateway_id = var.transit_gateway_id
    vpc_id = aws_vpc.main.id
    subnet_ids = var.vpc_name == "management" || var.vpc_name == "security" ? [for subnet in aws_subnet.public : subnet.id] : [for subnet in aws_subnet.private : subnet.id]

    tags = merge(local.common_tags, {
        Name = "${var.vpc_name}-tgw-attachment"
    })
}

# Direct Connect Gateway
resource "aws_dx_gateway" "main" {
    name = "main-dxgw"
    amazon_side_asn = 64512
}

# TGW-DX Gateway Association
resource "aws_dx_gateway_association" "main" {
    dx_gateway_id = aws_dx_gateway.main.id
    associated_gateway_id = var.transit_gateway_id
    allowed_prefixes = var.allowed_prefixes
}

# Route through TGW
resource "aws_route" "tgw_routes" {
    for_each = { for combo in local.route_table_cidr_combinations : combo.key => combo }

    route_table_id = each.value.route_table_id
    destination_cidr_block = each.value.cidr_block
    transit_gateway_id = var.transit_gateway_id
}


