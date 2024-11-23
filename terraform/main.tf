# VPCs 
module "vpcs" {
    for_each = var.vpc_configs
    source = "./modules/networking"

    vpc_name = each.key
    vpc_cidr = each.value.cidr_block
    availability_zones = local.azs
    public_subnets = each.value.public_subnets
    private_subnets = each.value.private_subnets
    enable_nat_gateway = each.value.enable_nat_gateway
    enable_igw = each.value.enable_igw
    transit_gateway_id = aws_ec2_transit_gateway.main.id
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
    description = "Main Transit Gateway"
    amazon_side_asn = 64514
    tags = merge(local.common_tags, {
        Name = "main-tgw"
    })
}

# EKS
module "eks" {
    source = "terraform-aws-modules/eks/aws"
    version = "~> 19.0"

    cluster_name = "banking-eks"
    cluster_version = "1.27"
    enable_irsa = true

    vpc_id = module.vpcs["production"].vpc_id
    subnet_ids = module.vpcs["production"].private_subnet_ids

    eks_managed_node_groups = {
        general = {
            desired_size = 2
            min_size = 1
            max_size = 3
            
            instance_types = ["t3.medium"]
            capacity_type = "ON_DEMAND"
        }
    }

    tags = merge(local.common_tags, {
        Name = "EKS"
    })
}

# API Module
module "api" {
    source = "./modules/api"
    api_log_group_arn = module.monitoring.api_log_group_arn
    fraud_detection_invoke_arn = module.compute.fraud_detection_invoke_arn
}   

# Compute Module
module "compute" {
    source = "./modules/compute"
    management_public_subnet_ids = module.vpcs["management"].public_subnet_ids
    management_vpc_id = module.vpcs["management"].vpc_id
    bastion_instance_profile_role = module.security.bastion_instance_profile_role
    production_public_subnet_ids = module.vpcs["production"].public_subnet_ids
    alb_bucket_id = module.storage.alb_bucket_id
    production_vpc_id = module.vpcs["production"].vpc_id
    lambda_role_arn = module.security.lambda_role_arn
    dynamodb_table_name = module.database.dynamodb_table_name
    sns_topic_arn = module.monitoring.sns_topic_arn
    rest_api_id = module.api.rest_api_id
    cloudwatch_event_rule_macie_findings_arn = module.monitoring.cloudwatch_event_rule_macie_findings_arn
    eks_security_group_id = module.eks.cluster_security_group_id
    cloudtrail_bucket_arn = module.storage.cloudtrail_bucket_arn
    audit_reports_bucket_arn = module.storage.audit_reports_bucket_arn
    vpc_flow_logs_bucket_arn = module.storage.vpc_flow_logs_bucket_arn
    alb_s3_bucket_policy = module.security.alb_s3_bucket_policy
    cluster_name = module.eks.cluster_name 
    eks_service_account_role_arn = module.security.eks_service_account_role_arn
}

# Database Module
module "database" {
    source = "./modules/database"

    data_vpc_id = module.vpcs["data"].vpc_id
    eks_security_group_id = module.eks.cluster_security_group_id
    private_subnet_ids = {
        data = module.vpcs["data"].private_subnet_ids
    }
    lambda_sg_id = module.compute.lambda_sg_id
    database_kms_key_arn = module.security.database_kms_key_arn
    database_kms_key_id = module.security.database_kms_key_id
    audit_reports_bucket_arn = module.storage.audit_reports_bucket_arn
    cloudtrail_bucket_arn = module.storage.cloudtrail_bucket_arn
    backup_role_arn = module.security.backup_role_arn
    production_vpc_cidr = module.vpcs["production"].vpc_cidr
}

# Monitoring Module
module "monitoring" {
    source = "./modules/monitoring"

    alb_arn = module.compute.alb_arn
    aurora_cluster_arn = module.database.aurora_cluster_arn
    web_acl_name = module.security.web_acl_name
    macie_classification_job_id = module.security.macie_classification_job_id
    network_firewall_arn = module.security.network_firewall_arn
    dynamodb_table_name = module.database.dynamodb_table_name
    macie_findings_arn = module.compute.macie_findings_arn
    config_rules_arn = module.compute.config_rules_arn
}

# Security Module
module "security" {
    source = "./modules/security"

    security_vpc_id = module.vpcs["security"].vpc_id
    security_subnet_ids = module.vpcs["security"].public_subnet_ids
    swift_endpoints = var.swift_endpoints
    payment_gateway_endpoints = var.payment_gateway_endpoints
    production_vpc_cidr = module.vpcs["production"].vpc_cidr
    alb_arn = module.compute.alb_arn
    cloudtrail_bucket_id = module.storage.cloudtrail_bucket_id
    firewall_logs_name = module.monitoring.network_firewall_logs_name
    sns_topic_arn = module.monitoring.sns_topic_arn
    dynamodb_table_name = module.database.dynamodb_table_name
    aurora_cluster_arn = module.database.aurora_cluster_arn
    api_log_group_arn = module.monitoring.api_log_group_arn
    eks_oidc_provider_arn = module.eks.oidc_provider_arn
    eks_cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
    audit_reports_bucket_name = module.storage.audit_reports_bucket_name
    eks_bucket_arn = module.storage.eks_bucket_arn
    cloudtrail_bucket_arn = module.storage.cloudtrail_bucket_arn
    vpc_flow_logs_bucket_arn = module.storage.vpc_flow_logs_bucket_arn
    audit_reports_bucket_arn = module.storage.audit_reports_bucket_arn
    cloudtrail_bucket_name = module.storage.cloudtrail_bucket_name
    alb_bucket_arn = module.storage.alb_bucket_arn
}

# Storage Module
module "storage" {
    source = "./modules/storage"
    
    vpc_ids = {
        production  = module.vpcs["production"].vpc_id
        data        = module.vpcs["data"].vpc_id
        management  = module.vpcs["management"].vpc_id
        security    = module.vpcs["security"].vpc_id
    }
    database_kms_key_arn = module.security.database_kms_key_arn
    production_vpc_id = module.vpcs["production"].vpc_id
    production_private_subnet_ids = module.vpcs["production"].private_subnet_ids
    vpc_cidr = module.vpcs["production"].vpc_cidr
    vpc_id = module.vpcs["production"].vpc_id
    vpc_name = module.vpcs["production"].vpc_name
}
