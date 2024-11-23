variable "management_public_subnet_ids" {
    type = list(string)
    description = "Public Subnet IDs in Management VPC"
}

variable "amazon_linux_2_ami" {
    type = string
    description = "AMI ID for Amazon Linux 2"
    default = null 
}   

variable "management_vpc_id" {
   type = string
   description = "Management VPC ID"
}

variable "bastion_instance_profile_role" {
    type = string
    description = "Bastion IAM Instance Profile Role"
    default = "bastionrole"
}

variable "production_public_subnet_ids" {
    type = list(string)
    description = "Public Subnet IDs in Production VPC"
}

variable "alb_bucket_id" {
    type = string
    description = "ALB Logs S3 Bucket ID"
}

variable "production_vpc_id" {
    type = string
    description = "Production VPC ID"
}

variable "region" {
    type = string
    default = "eu-west-2"
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

variable "dynamodb_table_name" {
    type = string
    description = "DynamoDB Table Name"
}

variable "sns_topic_arn" {
    type = string
    description = "SNS Topic ARN"
}

variable "lambda_role_arn" {
    type = string
    description = "IAM Role ARN for Lambda Function"
}

variable "rest_api_id" {
    type = string
    description = "API Gateway Rest API ID"
}

variable "cloudwatch_event_rule_macie_findings_arn" {
    type = string
    description = "CloudWatch Event Rule ARN for Macie Findings"
}

variable "eks_security_group_id" {
    type = string
}

variable "cloudtrail_bucket_arn" {
    type = string
}

variable "vpc_flow_logs_bucket_arn" {
    type = string
}

variable "audit_reports_bucket_arn" {
    type = string
}

variable "alb_s3_bucket_policy" {
    type = string
}

variable "cluster_name" {
    type = string
    description = "EKS Cluster Name"
}

variable "eks_service_account_role_arn" {
    type = string
    description = "IAM Role for EKS Service Account"
}