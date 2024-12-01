data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Lambda Function for Fraud Detection
resource "aws_lambda_function" "fraud_detection" {
  filename      = "${path.module}/../../../lambda/fraud-detection/fraud-detection.zip"
  function_name = "transaction-fraud-detection"
  role          = var.lambda_role_arn
  handler       = "app.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      SNS_TOPIC_ARN  = var.sns_topic_arn
    }
  }

  vpc_config {
    subnet_ids         = var.production_public_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fraud_detection.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${var.rest_api_id}/*"
}

# Lambda Function for Macie Findings
resource "aws_lambda_function" "macie_findings" {
  filename      = "${path.module}/../../../lambda/macie-findings/macie-findings.zip"
  function_name = "macie-sensitive-data-findings"
  role          = var.lambda_role_arn
  handler       = "app.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      S3_BUCKET_ARNS = join(",", [var.audit_reports_bucket_arn, var.vpc_flow_logs_bucket_arn, var.cloudtrail_bucket_arn])
      SNS_TOPIC_ARN  = var.sns_topic_arn
    }
  }

  vpc_config {
    subnet_ids         = var.production_public_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# Lambda Function for Config Rule Changes
resource "aws_lambda_function" "config_rules" {
  filename      = "${path.module}/../../../lambda/config-rule-changes/config-rule-changes.zip"
  function_name = "config-rule-changes"
  role          = var.lambda_role_arn
  handler       = "app.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      APPROVED_PORTS     = "80,443,22"
      VPC_ID             = var.production_vpc_id
      SNS_TOPIC_ARN      = var.sns_topic_arn
      ENVIRONMENT        = "production"
      SECURITY_GROUP_IDS = join(",", [var.eks_security_group_id, aws_security_group.alb.id]) # Critical SGs to monitor
    }
  }

  vpc_config {
    subnet_ids         = var.production_public_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# Lambda Permission to allow EventBridge invocation
resource "aws_lambda_permission" "allow_eventbridge" {
  for_each = {
    config = var.cloudwatch_event_rule_config_changes_arn
    macie  = var.cloudwatch_event_rule_macie_findings_arn
  }

  statement_id  = "AllowEventBridgeInvoke${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.key == "config" ? aws_lambda_function.config_rules.function_name : aws_lambda_function.macie_findings.function_name
  principal     = "events.amazonaws.com"
  source_arn    = each.value
}

