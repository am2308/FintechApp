# Redis
output "primary_endpoint" {
  value = aws_elasticache_replication_group.primary.primary_endpoint_address
}

output "reader_endpoint" {
  value = aws_elasticache_replication_group.primary.reader_endpoint_address
}

output "secondary_endpoint" {
  value = aws_elasticache_replication_group.secondary.primary_endpoint_address
}

# Main
output "aurora_cluster_arn" {
  value = aws_rds_cluster.global_bank_cluster.arn
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.banking.name
}