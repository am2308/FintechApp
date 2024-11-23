variable "vpc_configs" {
    description = "Configuration for all VPCs"
    type = map(object({
        cidr_block = string
        public_subnets = list(string)
        private_subnets = list(string)
        enable_nat_gateway = bool
        enable_igw = bool
    }))
    default = {
        "production" = {
            cidr_block = "10.1.0.0/16"
            public_subnets = ["10.1.1.0/24", "10.1.3.0/24"]
            private_subnets = ["10.1.2.0/24", "10.1.4.0/24"]
            enable_nat_gateway = true
            enable_igw = true
        }
        "data" = {
            cidr_block = "10.2.0.0/16"
            public_subnets = []
            private_subnets = ["10.2.1.0/24", "10.2.2.0/24"]
            enable_nat_gateway = false
            enable_igw = false
        }
        "management" = {
            cidr_block = "10.3.0.0/16"
            public_subnets = ["10.3.1.0/24", "10.3.3.0/24"]
            private_subnets = []
            enable_nat_gateway = false
            enable_igw = true
        }
        "security" = {
            cidr_block = "10.4.0.0/16"
            public_subnets = ["10.4.1.0/24", "10.4.3.0/24"]
            private_subnets = []
            enable_nat_gateway = false
            enable_igw = true
        }
    }
}

variable "region" {
    type = string
    default = "eu-west-2"
}

variable "secondary_region" {
    description = "Secondary AWS Region for Disaster Recovery"
    default = "eu-west-1"
}

variable "environment" {
    type = string
    default = "Dev"
}

locals {
    azs = ["${var.region}a", "${var.region}b"]
    common_tags = {
        Project = "Global Bank Migration"
        Environment = var.environment 
        Terraform = true
    }
}

# modules/security
variable "swift_endpoints" {
    type    = list(string)
    default = ["192.168.1.0/24"]  # Mock SWIFT
}

variable "payment_gateway_endpoints" {
    type    = list(string)
    default = ["192.168.2.0/24"]  # Mock Payment Gateway
}

locals {
    monitored_buckets = [
        "cloudtrail-bucket-talha",
        "vpc-flow-logs-talha",
        "audit-reports-talha"
    ]
}