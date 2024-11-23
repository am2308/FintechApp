provider "aws" {
    region = "eu-west-2"
}

provider "aws" {
    alias = "secondary"
    region = var.secondary_region
}

terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "5.66.0"
        }
    }
}