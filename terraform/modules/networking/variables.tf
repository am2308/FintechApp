variable "vpc_name" {
    type = string
}

variable "vpc_cidr" {
    type = string
}

variable "availability_zones" {
    type = list(string)    
}

variable "public_subnets" {
    type = list(string)
}

variable "private_subnets" {
    type = list(string)    
}

variable "enable_nat_gateway" {
    type = bool    
}

variable "enable_igw" {
    type = bool
}

variable "region" {
    type = string
    default = "eu-west-2"
}

variable "environment" {
    type = string
    default = "Dev"
}

variable "transit_gateway_id" {
    type = string
    description = "Transit Gateway ID"
}

locals {
    azs = ["${var.region}a", "${var.region}b"]
    common_tags = {
        Project = "Global Bank Migration"
        Environment = var.environment 
        Terraform = true
    }
}

variable "allowed_prefixes" {
    type    = list(string)
    default = ["192.132.0.0/16", "192.168.1.0/24"] 
}

locals {
    destination_cidr_blocks = {
        production = ["10.2.0.0/16", "10.3.0.0/16", "10.4.0.0/16"]  
        data       = ["10.1.0.0/16", "10.3.0.0/16", "10.4.0.0/16"]  
        management = ["10.1.0.0/16", "10.2.0.0/16", "10.4.0.0/16"]  
        security   = ["10.1.0.0/16", "10.2.0.0/16", "10.3.0.0/16"]  
    }

    
    route_table_cidr_combinations = flatten([
        for rt_key, rt in merge(
            var.vpc_name != "data" ? aws_route_table.public : {},
            var.vpc_name == "production" ? aws_route_table.private_nat : {},
            var.vpc_name == "data" ? { "private" = aws_route_table.private_no_internet[0] } : {}
        ) : [
            for cidr in local.destination_cidr_blocks[var.vpc_name] : {
                route_table_id = rt.id
                cidr_block = cidr
                key = "${rt_key}-${replace(cidr, "/", "-")}"
            }
        ]
    ])
}

