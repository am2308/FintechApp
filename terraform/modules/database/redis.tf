# Redis Security Group
resource "aws_security_group" "redis" {
    name = "redis-sg"
    description = "Security Group for Redis Cluster"
    vpc_id = var.data_vpc_id
    
    ingress {
        from_port = 6379
        to_port = 6379
        protocol = "tcp"
        cidr_blocks = [var.production_vpc_cidr]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = merge(local.common_tags, {
        Name = "Redis Security Group"
    })
}

# Redis Parameter Group
resource "aws_elasticache_parameter_group" "redis" {
    family = "redis7"
    name = "redis-parameter-group"
    description = "Redis Parameter Group for Global Banking"

    parameter {
        name = "maxmemory-policy"
        value = "volatile-lru"
    }

    parameter {
        name = "notify-keyspace-events"
        value = "AKE"
    }
}

# Redis Subnet Group
resource "aws_elasticache_subnet_group" "redis" {
    name = "redis-subnet-group"
    subnet_ids = var.private_subnet_ids["data"]
}

# Global Datastore
resource "aws_elasticache_global_replication_group" "global" {
    global_replication_group_id_suffix = "global-banking"
    primary_replication_group_id = aws_elasticache_replication_group.primary.id
}

# Primary Replication Group
resource "aws_elasticache_replication_group" "primary" {
    description = "Redis Primary Replication Group for Global Banking"
    replication_group_id = "redis-global-banking-primary"
    
    node_type = "cache.r6g.xlarge"
    port = 6379
    parameter_group_name = aws_elasticache_parameter_group.redis.name
    subnet_group_name = aws_elasticache_subnet_group.redis.name
    security_group_ids = [aws_security_group.redis.id]
    
    automatic_failover_enabled = true
    multi_az_enabled = true
    num_cache_clusters = 3
    at_rest_encryption_enabled = true
    transit_encryption_enabled = true
    kms_key_id = var.database_kms_key_id

    # Backup Configuration
    snapshot_retention_limit = 7
    snapshot_window = "00:00-05:00"
    maintenance_window = "mon:05:00-mon:09:00"

    tags = merge(local.common_tags, {
        Name = "Redis Primary Replication Group"
        Environment = var.environment
    })
}

# Secondary Replication Group
resource "aws_elasticache_replication_group" "secondary" {
    description = "Redis Secondary Replication Group for Global Banking"
    replication_group_id = "redis-global-banking-secondary"
    
    node_type = "cache.r6g.xlarge"
    engine_version = "7.0"
    port = 6379
    parameter_group_name = aws_elasticache_parameter_group.redis.name
    subnet_group_name = aws_elasticache_subnet_group.redis.name
    security_group_ids = [aws_security_group.redis.id]
    
    automatic_failover_enabled = true
    multi_az_enabled = true
    num_cache_clusters = 3
    at_rest_encryption_enabled = true
    transit_encryption_enabled = true
    kms_key_id = var.database_kms_key_id

    # Backup Configuration
    snapshot_retention_limit = 7
    snapshot_window = "00:00-05:00"
    maintenance_window = "mon:05:00-mon:09:00"

    tags = merge(local.common_tags, {
        Name = "Redis Secondary Replication Group"
        Environment = var.environment
    })
}


