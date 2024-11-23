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

variable "data_vpc_id" {
    type = string
    description = "Data VPC ID"
}

variable "database_kms_key_id" {
    type = string
    description = "Database KMS Key ID"
}

variable "eks_security_group_id" {
    type = string
    description = "EKS Security Group ID"
}

variable "private_subnet_ids" {
    type = map(list(string))
    description = "Private Subnet IDs per VPC"
}

variable "lambda_sg_id" {
    type = string
    description = "Lambda Security Group ID"
}

variable "database_kms_key_arn" {
    type = string
    description = "Database KMS Key ARN"
}

variable "audit_reports_bucket_arn" {
    type = string
    description = "S3 Bucket for Audit Reports"
}

variable "cloudtrail_bucket_arn" {
    type = string
    description = "S3 Bucket for CloudTrail API Logs"
}

variable "backup_role_arn" {
    type = string
    description = "IAM Role for AWS Backup"
}

variable "production_vpc_cidr" {
    type = string
}