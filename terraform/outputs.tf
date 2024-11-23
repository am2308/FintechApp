output "vpc_ids" {
    value = {
        for vpc_name, vpc in module.vpcs : vpc_name => vpc.vpc_id
    }
}

output "private_subnet_ids" {
    value = {
        for vpc_name, vpc in module.vpcs : vpc_name => vpc.private_subnet_ids
    }
}

output "public_subnet_ids" {
    value = {
        for vpc_name, vpc in module.vpcs : vpc_name => vpc.public_subnet_ids
    }
}

output "vpc_cidrs" {
    description = "Map of VPC names to CIDR blocks"
    value = {
        for vpc_name, vpc in module.vpcs : vpc_name => vpc.vpc_cidr
    }
}

output "vpc_names" {
    description = "Map of VPC names to their names from the module"
    value = {
        for vpc_name, vpc in module.vpcs : vpc_name => vpc.vpc_name
    }
}

output "cluster_endpoint" {
    value = module.eks.cluster_endpoint
}

output "cluster_name" {
    value = module.eks.cluster_name
}

output "eks_oidc_provider_arn" {
    value = module.eks.oidc_provider_arn
}

output "cluster_oidc_issuer_url" {
    value = module.eks.cluster_oidc_issuer_url
}

output "vpc_cidr_blocks" {
    description = "List of all VPC CIDR blocks"
    value = [for vpc_name, vpc in var.vpc_configs : vpc.cidr_block]
}
