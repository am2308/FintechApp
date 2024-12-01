# S3 Bucket for CloudTrail API Calls
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "cloudtrail-bucket-talha"

  tags = merge(local.common_tags, {
    Name = "CloudTrail Bucket"
  })
}

# Bucket Key for Cost Optimisation
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_key" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.database_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Rule for CloudTrail Bucket
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_config" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id = "cloudtrail-logs-archiving"

    filter {
      and {
        prefix = "cloudtrail-api-calls/"
        tags = {
          archive  = "true"
          datalife = "long"
        }
      }
    }
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555 # 7 Years
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER_IR"
    }

    noncurrent_version_transition {
      noncurrent_days = 365
      storage_class   = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = 2555 # 7 Years
    }
  }
}

# Enable S3 Versioning for CloudTrail Bucket
resource "aws_s3_bucket_versioning" "cloudtrail_versioning" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket for VPC Flow Logs
resource "aws_s3_bucket" "vpc_flow_logs" {
  bucket = "vpc-flow-logs-talha"
}

# Bucket Key for Cost Optimisation
resource "aws_s3_bucket_server_side_encryption_configuration" "vpcflowlogs_key" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.database_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Flow Logs for each VPC
resource "aws_flow_log" "vpcs" {
  for_each = var.vpc_ids

  log_destination      = aws_s3_bucket.vpc_flow_logs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = each.value

  destination_options {
    file_format        = "parquet"
    per_hour_partition = true
  }
}

# Lifecycle Rule for VPC Flow Logs Bucket
resource "aws_s3_bucket_lifecycle_configuration" "vpcflowlogs_config" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  rule {
    id     = "vpc-flow-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555 # 7 Years
    }
  }
}

# S3 Bucket for ALB Logs in Production VPC
resource "aws_s3_bucket" "alb" {
  bucket = "alb-logs-talha"
}

# Bucket Key for Cost Optimisation
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_key" {
  bucket = aws_s3_bucket.alb.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.database_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "alb" {
  bucket = aws_s3_bucket.alb.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Rule for ALB Logs Bucket
resource "aws_s3_bucket_lifecycle_configuration" "alb_config" {
  bucket = aws_s3_bucket.alb.id

  rule {
    id     = "alb-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555 # 7 Years
    }
  }
}


# S3 Bucket for Lambda CodePipeline Artifacts
resource "aws_s3_bucket" "lambda" {
  bucket = "lambda-artifacts-talha"
}

# Bucket Key for Cost Optimisation
resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_key" {
  bucket = aws_s3_bucket.lambda.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.database_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "lambda" {
  bucket = aws_s3_bucket.lambda.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Rule for Lambda Bucket
resource "aws_s3_bucket_lifecycle_configuration" "lambda_config" {
  bucket = aws_s3_bucket.lambda.id

  rule {
    id     = "lambda-artifacts"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 180
    }
  }
}

# S3 Bucket for EKS CodePipeline Artifacts
resource "aws_s3_bucket" "eks" {
  bucket = "eks-artifacts"
}

# Bucket Key for Cost Optimisation
resource "aws_s3_bucket_server_side_encryption_configuration" "eks_key" {
  bucket = aws_s3_bucket.eks.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.database_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "eks" {
  bucket = aws_s3_bucket.eks.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Rule for Lambda Bucket
resource "aws_s3_bucket_lifecycle_configuration" "eks_config" {
  bucket = aws_s3_bucket.eks.id

  rule {
    id     = "eks-artifacts"
    status = "Enabled"

    transition {
      days          = 60
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# S3 Bucket for Audit Reports
resource "aws_s3_bucket" "audit_reports" {
  bucket = "audit-reports-talha"
}

# Bucket Key for Cost Optimisation
resource "aws_s3_bucket_server_side_encryption_configuration" "audit_key" {
  bucket = aws_s3_bucket.audit_reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.database_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "audit" {
  bucket = aws_s3_bucket.audit_reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Rule for Audit Reports (CloudWatch, GuardDuty, Security Hub, Config)
resource "aws_s3_bucket_lifecycle_configuration" "audit_config" {
  bucket = aws_s3_bucket.audit_reports.id

  rule {
    id     = "lambda-artifacts"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555
    }
  }
}
