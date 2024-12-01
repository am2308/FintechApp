# kms.tf
output "database_kms_key_id" {
  description = "ID of database KMS key"
  value       = aws_kms_key.database.id
}

output "database_kms_key_arn" {
  description = "ARN of database KMS key"
  value       = aws_kms_key.database.arn
}

output "database_kms_alias_arn" {
  description = "ARN of database KMS alias"
  value       = aws_kms_alias.database.arn
}

output "application_kms_key_id" {
  description = "ID of application KMS key"
  value       = aws_kms_key.application.id
}

output "application_kms_key_arn" {
  description = "ARN of application KMS key"
  value       = aws_kms_key.application.arn
}

output "application_kms_alias_arn" {
  description = "ARN of application KMS alias"
  value       = aws_kms_alias.application.arn
}

# main.tf
output "web_acl_arn" {
  description = "ARN of WAF Web ACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_name" {
  value = aws_wafv2_web_acl.main.name
}
output "network_firewall_id" {
  description = "ID of Network Firewall"
  value       = aws_networkfirewall_firewall.main.id
}

output "macie_classification_job_id" {
  value = aws_macie2_classification_job.s3_sensitive_data.id
}

output "network_firewall_arn" {
  value = aws_networkfirewall_firewall.main.arn
}

# iam.tf
output "bastion_instance_profile_role" {
  description = "Bastion IAM Role"
  value       = aws_iam_role.bastion.name
}

output "backup_role_arn" {
  value = aws_iam_role.backup.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda.arn
}

output "alb_s3_bucket_policy" {
  value = aws_s3_bucket_policy.alb_logs_policy.policy
}

output "eks_service_account_role_arn" {
  value = aws_iam_role.eks_service_account.arn
}
