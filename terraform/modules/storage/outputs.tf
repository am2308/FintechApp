# S3
output "cloudtrail_bucket_arn" {
    value = aws_s3_bucket.cloudtrail.arn
}

output "cloudtrail_bucket_id" {
    value = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_bucket_name" {
    value = aws_s3_bucket.cloudtrail.bucket
}

output "vpc_flow_logs_bucket_arn" {
    value = aws_s3_bucket.vpc_flow_logs.arn
}

output "vpc_flow_logs_bucket_id" {
    value = aws_s3_bucket.vpc_flow_logs.id
}

output "alb_bucket_arn" {
    value = aws_s3_bucket.alb.arn
}

output "alb_bucket_id" {
    value = aws_s3_bucket.alb.id
}

output "lambda_bucket_arn" {
    value = aws_s3_bucket.lambda.arn
}

output "lambda_bucket_id" {
    value = aws_s3_bucket.lambda.id
}

output "eks_bucket_arn" {
    value = aws_s3_bucket.eks.arn
}

output "eks_bucket_id" {
    value = aws_s3_bucket.eks.id
}

output "audit_reports_bucket_arn" {
    value = aws_s3_bucket.audit_reports.arn
}

output "audit_reports_bucket_name" {
    value = aws_s3_bucket.audit_reports.bucket
}


# ECR

output "repository_urls" {
    value = {
        account_service  = aws_ecr_repository.account_service.repository_url
        transaction_service = aws_ecr_repository.transaction_service.repository_url
        auth_service = aws_ecr_repository.auth_service.repository_url
    }
    description = "URLs of ECR repositories for Kubernetes deployments"
}

output "registry_id" {
    value       = aws_ecr_repository.account_service.registry_id
    description = "ECR registry ID for IAM policies"
}