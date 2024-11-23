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

variable "security_vpc_id" {
    type = string
    description = "Security VPC ID"
}

variable "security_subnet_ids" {
    type = list(string)
    description = "Public Subnet IDs in Security VPC"
}

variable "alb_arn" {
    type = string
    description = "ALB ARN"
}

variable "production_vpc_cidr" {
    type = string
    description = "Production VPC Cidr"
}   

variable "swift_endpoints" {
    type = list(string)
}

variable "payment_gateway_endpoints" {
    type = list(string)
}

variable "cloudtrail_bucket_id" {
    type = string
    description = "CloudTrail Bucket ID"
}

variable "firewall_logs_name" {
    type = string
    description = "Network Firewall CloudWatch Log Group Name"
}

variable "dynamodb_table_name" {
    type = string
    description = "DynamoDB Table Name"
}

variable "sns_topic_arn" {
    type = string
    description = "SNS Topic ARN"
}

variable "aurora_cluster_arn" {
    type = string
    description = "Aurora Cluster ARN"
}

variable "api_log_group_arn" {
    type = string
    description = "API Gateway CloudWath Log Group ARN"
}

variable "eks_oidc_provider_arn" {
    type = string
    description = "ARN of EKS OIDC Provider"
}

variable "eks_cluster_oidc_issuer_url" {
    type = string
    description = "URL of EKS OIDC Provider"
}   

variable "audit_reports_bucket_name" {
    type = string
    description = "S3 Bucket for Config Audit Reports"
}

variable "eks_bucket_arn" {
    type = string
    description = "S3 Bucket for EKS CodePipeline Artifacts"
}

variable "audit_reports_bucket_arn" {
    type = string
}

variable "vpc_flow_logs_bucket_arn" {
    type = string
}

variable "cloudtrail_bucket_arn" {
    type = string
}

locals {
    monitored_buckets = [
        "cloudtrail-bucket-talha",
        "vpc-flow-logs-talha",
        "audit-reports-talha"
    ]
}

variable "cloudtrail_bucket_name" {
    type = string
}

variable "alb_bucket_arn" {
    type = string
}

