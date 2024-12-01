variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "secondary_region" {
  description = "Secondary AWS Region for Disaster Recovery"
  default     = "eu-west-1"
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

variable "api_log_group_arn" {
  type        = string
  description = "API Gateway CloudWatch Log Group ARN"
}

variable "fraud_detection_invoke_arn" {
  type        = string
  description = "ARN of Lambda Permission to allow API Gateway to invoke Lambda Fraud Detection"
}