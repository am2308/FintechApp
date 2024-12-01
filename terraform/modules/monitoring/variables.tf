variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "environment" {
  type    = string
  default = "Dev"
}

locals {
  azs = ["${var.region}a", "${var.region}b"]
  common_tags = {
    Project     = "Global Bank Migration"
    Environment = var.environment
    Terraform   = true
  }
}

variable "alb_arn" {
  type        = string
  description = "Production VPC ALB ARN"
}

variable "aurora_cluster_arn" {
  type        = string
  description = "Aurora Cluster ARN"
}

variable "web_acl_name" {
  type        = string
  description = "WAF Web ACL Name"
}

variable "macie_classification_job_id" {
  type        = string
  description = "Macie Sensitive Data Job ID"
}

variable "network_firewall_arn" {
  type        = string
  description = "Network Firewall ARN"
}

variable "dynamodb_table_name" {
  type        = string
  description = "DynamoDB Global Table Name"
}

variable "macie_findings_arn" {
  type        = string
  description = "Lambda Function ARN for Macie Findings"
}

variable "config_rules_arn" {
  type        = string
  description = "Lambda Function ARN for Config Rule Changes"
}