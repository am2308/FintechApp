# API

# API Gateway Role and Policy 
resource "aws_iam_role" "api_gateway_role" {
    name = "api-gateway-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "apigateway.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_policy" "api_gateway_policy" {
    name = "api-gateway-policy"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "elasticloadbalancing:DescribeLoadBalancers",
                    "elasticloadbalancing:DescribeTargetGroups",
                    "elasticloadbalancing:DescribeTargetHealth"
                ]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams",
                    "logs:PutLogEvents",
                    "logs:GetLogEvents",
                    "logs:FilterLogEvents"
                ]
                Resource = [
                    var.api_log_group_arn,
                    "${var.api_log_group_arn}:*"
                ]
            }   
        ]
    })
}

resource "aws_iam_role_policy_attachment" "api_gateway_attach" {
    role = aws_iam_role.api_gateway_role.name
    policy_arn = aws_iam_policy.api_gateway_policy.arn
}

# COMPUTE

# IAM Role for EKS Secrets Access
resource "aws_iam_role" "secrets_access" {
    name = "eks-secrets-access"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "eks.amazonaws.com"
            }
        }
        ]
    })
}

resource "aws_iam_role_policy" "secrets_access" {
    name = "eks-secrets-access"
    role = aws_iam_role.secrets_access.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Effect = "Allow"
            Action = [
                "secretsmanager:GetSecretValue"
            ]
            Resource = [
                "arn:aws:secretsmanager:eu-west-2:*:secret:banking-secrets*"
            ]
        }
        ]
    })
}

# IAM Role for Bastion
resource "aws_iam_role" "bastion" {
    name = "bastionrole"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
    role       = aws_iam_role.bastion.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "bastion_cloudwatch" {
    role       = aws_iam_role.bastion.name
    policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Role for Systems Manager Session Manager
resource "aws_iam_role" "session_manager" {
    name = "session-manager-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "session_manager" {
    role       = aws_iam_role.session_manager.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup" {
    name = "backup-service-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "backup.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "backup" {
    role = aws_iam_role.backup.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
    name = "lambda-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "lambda.amazonaws.com"
                }
            }
        ]
    })
}

# IAM Policy for Lambda Fraud Function
resource "aws_iam_policy" "lambda_fraud" {
    name = "lambda-fraud-policy"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "dynamodb:Query",
                    "dynamodb:PutItem"        
                ]
                Resource = var.dynamodb_table_name
            },
            {
                Effect = "Allow"
                Action = [
                    "sns:Publish"
                ]
                Resource = [var.sns_topic_arn]
            }
        ]
    })
}

# IAM Policy for Lambda Macie Function
resource "aws_iam_policy" "lambda_macie" {
    name = "lambda-macie-policy"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "s3:PutEncryptionConfiguration",
                    "s3:GetEncryptionConfiguration",
                    "s3:GetBucketEncryption"        
                ]
                Resource = [
                    "${var.cloudtrail_bucket_arn}",
                    "${var.vpc_flow_logs_bucket_arn}",
                    "${var.audit_reports_bucket_arn}"
                ]
            },
            {
                Effect = "Allow"
                Action = [
                    "sns:Publish"
                ]
                Resource = [var.sns_topic_arn]
            },
            {
                Effect = "Allow"
                Action = [
                    "securityhub:BatchImportFindings",
                    "securityhub:UpdateFindings"
                ]
                Resource = "*"
            }
        ]
    })
}

# IAM Policy for Lambda Config Function
resource "aws_iam_policy" "lambda_config" {
    name = "lambda-config-policy"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "ec2:DescribeSecurityGroups",
                    "ec2:RevokeSecurityGroupIngress",
                    "ec2:UpdateSecurityGroupRuleDescriptionsIngress"        
                ]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [
                    "sns:Publish"
                ]
                Resource = [var.sns_topic_arn]
            },
            {
                Effect= "Allow"
                Action = [
                    "config:GetResourceConfigHistory",
                    "config:GetResourceConfig"
                ]
                Resource = "arn:aws:config:eu-west-2:463470963000:config-rule/config-rule-id"

            }
        ]
    })
}

# Attach Policies to Role
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
    role = aws_iam_role.lambda.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_fraud" {
    role = aws_iam_role.lambda.name
    policy_arn = aws_iam_policy.lambda_fraud.arn
}

resource "aws_iam_role_policy_attachment" "lambda_macie" {
    role = aws_iam_role.lambda.name
    policy_arn = aws_iam_policy.lambda_macie.arn
}

resource "aws_iam_role_policy_attachment" "lambda_config" {
    role = aws_iam_role.lambda.name
    policy_arn = aws_iam_policy.lambda_config.arn
}

# EKS Cluster Role
resource "aws_iam_role" "eks_cluster" {
    name = "eks-cluster-role"

    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
        Service = "eks.amazonaws.com"
        }
    }]
    })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role       = aws_iam_role.eks_cluster.name
}

# EKS Node Role
resource "aws_iam_role" "eks_node" {
    name = "eks-node-role"

    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
            Service = "ec2.amazonaws.com"
            }
        }]
    })
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
    for_each = toset([
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        ])

    policy_arn = each.value
    role       = aws_iam_role.eks_node.name
}

# Service Account Role (for pod IAM)
resource "aws_iam_role" "eks_service_account" {
 name = "eks-service-account-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRoleWithWebIdentity"
            Effect = "Allow"
            Principal = {
                Federated = var.eks_oidc_provider_arn
            }
            Condition = {
                StringEquals = {
                    "${var.eks_cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com",
                    "${var.eks_cluster_oidc_issuer_url}:sub" = "system:serviceaccount:default:my-service-account"
                }
            }
        }]
    })
}

# Policies for Service Accounts
resource "aws_iam_policy" "dynamodb_eks" {
    name = "dynamodb-eks-policy"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "dynamodb:GetItem",
                    "dynamodb:PutItem",
                    "dynamodb:Query"
                ]
                Resource = var.dynamodb_table_name
            }
        ]
    })
}

resource "aws_iam_policy" "s3_eks" {
    name = "s3-eks-policy"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "s3:GetObject",
                    "s3:PutObject"
                ]
                Resource = [
                    "${var.eks_bucket_arn}",
                    "${var.eks_bucket_arn}/*"
                ]

            }
        ]
    })
}

resource "aws_iam_policy" "aurora_eks" {
    name = "aurora-eks-policy"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "rds-data:ExecuteStatement",
                    "rds-data:BatchExecuteStatement"
                ]
                Resource = var.aurora_cluster_arn
            }
        ]
    })
}

resource "aws_iam_policy" "alb_controller" {
    name = "ALBControllerPolicy"
    
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "elasticloadbalancing:CreateLoadBalancer",
                    "elasticloadbalancing:DeleteLoadBalancer",
                    "elasticloadbalancing:DescribeLoadBalancers",
                    "elasticloadbalancing:CreateTargetGroup",
                    "elasticloadbalancing:DeleteTargetGroup",
                    "elasticloadbalancing:DescribeTargetGroups",
                    "elasticloadbalancing:RegisterTargets",
                    "elasticloadbalancing:DeregisterTargets",
                    "elasticloadbalancing:CreateListener",
                    "elasticloadbalancing:DeleteListener",
                    "elasticloadbalancing:DescribeListeners",
                    "elasticloadbalancing:ModifyListener"
                    ]
                    Resource = [
                        "arn:aws:elasticloadbalancing:${var.region}:${data.aws_caller_identity.current.account_id}:loadbalancer/app/*",
                        "arn:aws:elasticloadbalancing:${var.region}:${data.aws_caller_identity.current.account_id}:targetgroup/*",
                        "arn:aws:elasticloadbalancing:${var.region}:${data.aws_caller_identity.current.account_id}:listener/*"
                    ]
            },
            {
                Effect   = "Allow"
                Action   = [
                    "ec2:DescribeInstances",
                    "ec2:DescribeSecurityGroups",
                    "ec2:AuthorizeSecurityGroupIngress",
                    "ec2:RevokeSecurityGroupIngress"
                ]
                Resource = "*"
            },
            {
                Effect   = "Allow"
                Action   = [
                    "acm:DescribeCertificate",
                    "acm:ListCertificates",
                    "acm:GetCertificate"
                ]
                Resource = [
                "arn:aws:acm:${var.region}:${data.aws_caller_identity.current.account_id}:certificate/*"
                ]
            },
            {
                Effect   = "Allow"
                Action   = [
                "wafv2:GetWebACL",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL"
                ]
                Resource = [
                "arn:aws:wafv2:${var.region}:${data.aws_caller_identity.current.account_id}:regional/webacl/*"
                ]
                Resource = "*"
            }
        ]
    })
}

# Attach Policies to EKS Service Role
resource "aws_iam_role_policy_attachment" "dynamodb" {
    role = aws_iam_role.eks_service_account.name
    policy_arn = aws_iam_policy.dynamodb_eks.arn
}

resource "aws_iam_role_policy_attachment" "aurora" {
    role = aws_iam_role.eks_service_account.name
    policy_arn = aws_iam_policy.aurora_eks.arn
}

resource "aws_iam_role_policy_attachment" "s3_eks" {
    role = aws_iam_role.eks_service_account.name
    policy_arn = aws_iam_policy.s3_eks.arn
}

# Monitoring
resource "aws_iam_role" "monitoring_roles" {
    for_each = toset([
        "elasticloadbalancing",
        "rds",
        "waf",
        "macie",
        "network-firewall",
        "dynamodb",
        "lambda",
        "apigateway"
    ])

    name = "${each.key}-cloudwatch-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "${each.key}.amazonaws.com"
            }
        }]
    })
}

# Attach CloudWatch Policies to each role
resource "aws_iam_role_policy" "cloudwatch_policy" {
    for_each = aws_iam_role.monitoring_roles

    name = "cloudwatch-policy"
    role = each.value.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Action = [
                "cloudwatch:PutMetricData",
                "logs:CreateLogGroup",
                "logs:CreatelogStream",
                "logs:PutLogEvents"   
            ]
            Resource = "*"
        }]
    })
}

# Config Role
resource "aws_iam_role" "config" {
    name = "AWSConfigRole"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "config.amazonaws.com"
            }
        }]
    })
}

# Policy for Config to access S3 Bucket Audit Reports
resource "aws_iam_role_policy" "config_s3_permissions" {
    role = aws_iam_role.config.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect   = "Allow"
                Action   = [
                    "s3:PutObject", 
                    "s3:GetBucketLocation", 
                    "s3:ListBucket"
                ]
                Resource = [
                "arn:aws:s3:::${var.audit_reports_bucket_name}",
                "arn:aws:s3:::${var.audit_reports_bucket_name}/*"
                ]
            },
            {
                Effect   = "Allow",
                Action   = [
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:GenerateDataKey*",
                "kms:DescribeKey"
                ]
                Resource = "${aws_kms_key.database.arn}"
            }
        ]
    })
}


resource "aws_iam_role_policy_attachment" "config_role_policy" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# S3 Bucket Policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail_policy" {
    bucket = var.cloudtrail_bucket_name

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "cloudtrail.amazonaws.com"
                }
                Action = "s3:PutObject"
                Resource = "${var.cloudtrail_bucket_arn}/AWSLogs/463470963000/*",
                Condition = {
                    StringEquals = {
                        "s3:x-amz-acl" = "bucket-owner-full-control",
                        "aws:SourceArn" = "arn:aws:cloudtrail:eu-west-2:${data.aws_caller_identity.current.account_id}:trail/global-banking-cloudtrail"
                    }
                }
            },
            {
                Effect = "Allow"
                Principal = {
                    Service = "cloudtrail.amazonaws.com"
                }
                Action = "s3:GetBucketAcl"
                Resource = "${var.cloudtrail_bucket_arn}"
                Condition = {
                    StringEquals = {
                        "aws:SourceArn" = "arn:aws:cloudtrail:eu-west-2:${data.aws_caller_identity.current.account_id}:trail/global-banking-cloudtrail"
                    }
                }
            }
        ]
    })
}

# S3 Bucket Policy for ALB Logs
resource "aws_s3_bucket_policy" "alb_logs_policy" {
    bucket = "alb-logs-talha"

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Principal = {
                    AWS = "arn:aws:iam::652711504416:root"
                },
                Action = [
                    "s3:PutObject",
                ]
                Resource = [
                    "${var.alb_bucket_arn}",
                    "${var.alb_bucket_arn}/*"
                ]
            },
            {
                Effect = "Allow"
                Principal = {
                    Service = "delivery.logs.amazonaws.com"
                }
                Action   = "s3:PutObject"
                Resource = "${var.alb_bucket_arn}/*"
                Condition = {
                    StringEquals = {
                        "s3:x-amz-acl" = "bucket-owner-full-control"
                    }
                }
            },
            {
                Effect    = "Allow"
                Principal = {
                    Service = "delivery.logs.amazonaws.com"
                }
                Action   = "s3:GetBucketAcl"
                Resource = "${var.alb_bucket_arn}}"
            }
        ]
    })
}
