# RDS Aurora Cluster
resource "aws_rds_cluster" "global_bank_cluster" {
    cluster_identifier = "global-bank-cluster"
    engine = "aurora-postgresql"
    engine_version = "15.3"
    database_name = "bankdatabase"
    master_username = "username"
    master_password = "password"
    port = 5432

    vpc_security_group_ids = [aws_security_group.aurora_sg.id]
    db_subnet_group_name = aws_db_subnet_group.aurora_subnet.name
    db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.banking.name

    backup_retention_period = 7
    preferred_backup_window = "03:00-04:00"
    skip_final_snapshot = true
    storage_encrypted = true 

    enabled_cloudwatch_logs_exports = [ "postgresql" ]
    kms_key_id = var.database_kms_key_arn

    tags = merge(local.common_tags, {
        Name = "Aurora Cluster"
    })
}

# Aurora Instance
resource "aws_rds_cluster_instance" "global_bank_instance" {
    count = 2
    identifier = "global-bank-write-${count.index}"
    cluster_identifier = aws_rds_cluster.global_bank_cluster.id
    instance_class = "db.r6g.large"
    engine = aws_rds_cluster.global_bank_cluster.engine 
    engine_version = aws_rds_cluster.global_bank_cluster.engine_version 

    tags = merge(local.common_tags, {
        Name = "Aurora Instance"
    })
}

# Aurora Read Replica Instance
resource "aws_rds_cluster_instance" "global_bank_read_replica" {
    count               = 2 
    identifier          = "global-bank-read-${count.index}"
    cluster_identifier  = aws_rds_cluster.global_bank_cluster.id
    instance_class      = "db.r6g.large"
    engine             = aws_rds_cluster.global_bank_cluster.engine
    engine_version     = aws_rds_cluster.global_bank_cluster.engine_version
    
    promotion_tier     = 1
    
    performance_insights_enabled = true
    performance_insights_retention_period = 7
    
    tags = merge(local.common_tags, {
        Name = "Aurora Read Replica"
        Role = "ReadReplica"
    })
}

# Aurora Security Group
resource "aws_security_group" "aurora_sg" {
    name = "aurora-sg"
    description = "Security Group for Aurora Cluster"
    vpc_id = var.data_vpc_id

    ingress {
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        cidr_blocks = [var.production_vpc_cidr]
    }

    tags = merge(local.common_tags, {
        Name = "Aurora Security Group"
    })
}

# Aurora Subnet Group
resource "aws_db_subnet_group" "aurora_subnet" {
    name = "bank-aurora-subnet-group"
    subnet_ids = var.private_subnet_ids["data"]

    tags = merge(local.common_tags, {
        Name = "Aurora Subnet Group"
    })
}

# Parameter Group for PostgreSQL Optimisations
resource "aws_rds_cluster_parameter_group" "banking" {
    family = "aurora-postgresql15"
    name = "bank-parameters-talha2"

    # Security Parameters
    parameter {
        name = "ssl_min_protocol_version"
        value = "TLSv1.2"
    }
    parameter {
      name = "rds.force_ssl"
      value = "1"
    }

    # Logging and Auditing
    parameter {
        name = "log_statement"
        value = "all"
    }
    parameter {
        name = "log_min_duration_statement"
        value = "1000" # Log queries taking more than one second
        apply_method = "immediate"
    }
    parameter {
        name = "log_connections"
        value = "1"
    }
    parameter {
        name = "log_disconnections"
        value = "1"
    }

    # Performance & Stability
    parameter {
        name = "max_connections"
        value = "GREATEST({DBInstanceClassMemory/95313392}, 5000)"
        apply_method = "pending-reboot"
    }
    parameter {
        name = "shared_buffers"
        value = "{DBInstanceClassMemory/32768}"
        apply_method = "pending-reboot"
    }
    parameter {
        name = "work_mem"
        value = "32768" # 32MB
    }
    parameter {
        name = "maintenance_work_mem"
        value = "262144" # 256MB
    }

    # Transaction Management
    parameter {
        name = "idle_in_transaction_session_timeout"
        value = "7200000" # 2 hours
    }
    parameter {
        name = "statement_timeout"
        value = "600000" # 10 minutes
    }

    lifecycle {
      create_before_destroy = true
    }

    tags = merge(local.common_tags, {
        Name = "Aurora Banking Parameter Group"
    })
}

# DynamoDB Global Tables
resource "aws_dynamodb_table" "banking" {
    name = "banking-global-table-talha"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "pk"
    range_key = "sk"
    stream_enabled = true
    stream_view_type = "NEW_AND_OLD_IMAGES"

    attribute {
        name = "pk"
        type = "S"
    }

    attribute {
        name = "sk"
        type = "S"
    }

    global_secondary_index {
        name               = "session_id_index"
        hash_key           = "session_id"
        projection_type    = "ALL"
    }

    global_secondary_index {
        name               = "user_id_index"
        hash_key           = "user_id"
        projection_type    = "ALL"
    }

    global_secondary_index {
        name               = "transaction_id_index"
        hash_key           = "transaction_id"
        projection_type    = "ALL"
    }

    global_secondary_index {
        name               = "timestamp_index"
        hash_key           = "timestamp"
        projection_type    = "ALL"
    }


    attribute {
        name = "session_id"
        type = "S"
    }

    attribute {
        name = "user_id"
        type = "S"
    }

    attribute {
        name = "transaction_id"
        type = "S"
    }

    attribute {
        name = "timestamp"
        type = "N"
    }

    replica {
        region_name = "eu-west-2"
        kms_key_arn = var.database_kms_key_arn
    }

    replica {
        region_name = "eu-west-1"
        kms_key_arn = var.database_kms_key_arn
    }

    server_side_encryption {
        enabled = true
        kms_key_arn = var.database_kms_key_arn
    }

    tags = merge(local.common_tags, {
        Name = "DynamoDB Global Tables"
    })
}

# Backup Vault Primary Region
resource "aws_backup_vault" "primary" {
    name = "banking-backup-vault-primary"
    kms_key_arn = var.database_kms_key_arn

    tags = merge(local.common_tags, {
        Service = "Backup Primary"
    })
}

# Backup Vault Secondary Region (DR)
resource "aws_backup_vault" "secondary" {
    name = "banking-backup-vault-dr"
    kms_key_arn = var.database_kms_key_arn

    tags = merge(local.common_tags, {
        Service = "Backup DR"
    })
}

# Backup Plan Primary Region
resource "aws_backup_plan" "cross_region" {
    name = "banking-backup-plan-cross-region"

    rule {
        rule_name = "daily_backup_with_replication"
        target_vault_name = aws_backup_vault.primary.name
        schedule = "cron(0 5 ? * * *)" # Daily at 5 AM
      
        lifecycle {
            delete_after = 90
        }

        copy_action {
            destination_vault_arn = aws_backup_vault.secondary.arn
            lifecycle {
                delete_after = 90
            }
        }
    }

    rule {
        rule_name = "weekly_backup"
        target_vault_name = aws_backup_vault.primary.name
        schedule = "cron(0 5 ? * 1 *)" # Sunday at 5AM

        lifecycle {
          delete_after = 365
        }
    }

    advanced_backup_setting {
      backup_options = {
        WindowsVSS = "enabled"
      }
      resource_type = "EC2"
    }
    
}

# Backup Selection Primary Region
resource "aws_backup_selection" "cross_region" {
    name = "banking-backup-selection"
    iam_role_arn = var.backup_role_arn
    plan_id = aws_backup_plan.cross_region.id

    selection_tag {
        type = "STRINGEQUALS"
        key = "BACKUP"
        value = "true"
    }

    resources = flatten([
        aws_rds_cluster.global_bank_cluster.arn,
        [for i in range(length(aws_rds_cluster_instance.global_bank_read_replica)) : aws_rds_cluster_instance.global_bank_read_replica[i].arn],
        aws_dynamodb_table.banking.arn,
        aws_elasticache_replication_group.primary.arn,
        aws_elasticache_replication_group.secondary.arn,
        var.audit_reports_bucket_arn,
        var.cloudtrail_bucket_arn
    ])
}

