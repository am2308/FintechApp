locals {
    azs = ["${var.region}a", "${var.region}b"]
    common_tags = {
        Project = "Global Bank Migration"
        Environment = var.environment 
        Terraform = true
    }
}

variable "region" {
    type = string
    default = "eu-west-2"
}

variable "environment" {
    type = string
    default = "Dev"
}

variable "vpc_ids" {
    type = map(string)
    description = "Map of VPC Names to VPC IDs"
}
 
variable "database_kms_key_arn" {
    type = string
    description = "Database KMS Key ARN"
}

variable "production_vpc_id" {
    type = string
    description = "Production VPC ID"
}

variable "production_private_subnet_ids" {
    type = list(string)
    description = "ID of Private Subnets in Production VPC"
}

variable "vpc_name" {
    type = string
}

variable "vpc_cidr" {
    type = string
}

variable "vpc_id" {
    type = string
}

locals {
    monitored_buckets = [
        "cloudtrail-bucket-talha",
        "vpc-flow-logs-talha",
        "audit-reports-talha"
    ]
}