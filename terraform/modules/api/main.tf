# API Gateway Configuration

# Rest API
resource "aws_api_gateway_rest_api" "banking" {
    name = "banking-api"
    description = "Banking System API"
    
    endpoint_configuration {
        types = ["REGIONAL"]
    }
}

# Custom Domain
resource "aws_api_gateway_domain_name" "banking" {
    domain_name = "api.banking-domain.com"
    certificate_arn = aws_acm_certificate.api_certificate.arn
    endpoint_configuration {
        types = ["EDGE"]
    }
}

resource "aws_acm_certificate" "api_certificate" {
    domain_name = "api.banking-domain.com"
    validation_method = "DNS"
}

# API Key for external services/partners
resource "aws_api_gateway_api_key" "partner" {
    name = "partner-api-key"
}

# Usage Plan with throttling
resource "aws_api_gateway_usage_plan" "banking" {
    name = "banking-usage-plan"

    api_stages {
        api_id = aws_api_gateway_rest_api.banking.id
        stage = aws_api_gateway_stage.prod.stage_name
    }

    quota_settings {
        limit = 100000000
        period = "DAY"
    }

    throttle_settings {
        burst_limit = 5000
        rate_limit = 1000
    }
}

# Resources and Methods for Lambda integration
resource "aws_api_gateway_resource" "fraud" {
    rest_api_id = aws_api_gateway_rest_api.banking.id
    parent_id = aws_api_gateway_rest_api.banking.root_resource_id
    path_part = "fraud-check"
}

resource "aws_api_gateway_method" "fraud_post" {
    rest_api_id = aws_api_gateway_rest_api.banking.id
    resource_id = aws_api_gateway_resource.fraud.id
    http_method = "POST"
    authorization = "AWS_IAM"
    api_key_required = true
}

# Lambda Integration
resource "aws_api_gateway_integration" "fraud_lambda" {
    rest_api_id = aws_api_gateway_rest_api.banking.id
    resource_id = aws_api_gateway_resource.fraud.id
    http_method = aws_api_gateway_method.fraud_post.http_method
 
    integration_http_method = "POST"
    type = "AWS_PROXY"
    uri = var.fraud_detection_invoke_arn
}

# API Gateway Stages
resource "aws_api_gateway_stage" "prod" {
    deployment_id = aws_api_gateway_deployment.main.id
    rest_api_id  = aws_api_gateway_rest_api.banking.id
    stage_name = "prod"

        # Access Logging
            access_log_settings {
                destination_arn = var.api_log_group_arn
                format = jsonencode({
                    requestId            = "$context.requestId"
                    ip                  = "$context.identity.sourceIp"
                    caller              = "$context.identity.caller"
                    user                = "$context.identity.user"
                    requestTime         = "$context.requestTime"
                    httpMethod          = "$context.httpMethod"
                    resourcePath        = "$context.resourcePath"
                    status             = "$context.status"
                    protocol           = "$context.protocol"
                    responseLength     = "$context.responseLength"
                    integrationLatency = "$context.integrationLatency"
                })
            }

        cache_cluster_enabled = true
        cache_cluster_size   = "118" 

        xray_tracing_enabled = true

        variables = {
        "environment" = "production"
        }

        tags = merge(local.common_tags, {
            Name = "API Gateway Stage"
        })
}

# Stage deployment
resource "aws_api_gateway_deployment" "main" {
    rest_api_id = aws_api_gateway_rest_api.banking.id

    depends_on = [
    aws_api_gateway_integration.fraud_lambda,
    ]

    lifecycle {
        create_before_destroy = true
    }
}

# Method Settings (applies to all methods in stage)
resource "aws_api_gateway_method_settings" "all" {
    rest_api_id = aws_api_gateway_rest_api.banking.id
    stage_name  = aws_api_gateway_stage.prod.stage_name
    method_path = "*/*"

    settings {
        metrics_enabled        = true
        logging_level         = "INFO"
        data_trace_enabled    = true
        throttling_burst_limit = 5000
        throttling_rate_limit  = 1000
    }
}