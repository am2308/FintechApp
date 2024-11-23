# CloudWatch Log Group for ALB
resource "aws_cloudwatch_log_group" "alb" {
    name = "/aws/alb"
    retention_in_days = 90
    tags = merge(local.common_tags, {
        Service = "alb"
        Type = "logs"
    })
}

# ALB Alarms
resource "aws_cloudwatch_metric_alarm" "alb_errors" {
    alarm_name = "alb-errors"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "2"
    metric_name = "HTTPCode_ELB_5XX_Count"
    namespace = "AWS/ELB"
    period = "300"
    statistic = "Sum"
    threshold = "5"
    alarm_description = "ALB 5XX Errors"

    dimensions = {
      LoadBalancer = var.alb_arn
    }

    alarm_actions = [aws_sns_topic.banking_alerts.arn]
    tags = merge(local.common_tags, {
        Service = "alb"
        Type = "alarm"
    })
}

# CloudWatch Log Group for Aurora
resource "aws_cloudwatch_log_group" "aurora" {
    name = "/aws/aurora"
    retention_in_days = 90
    tags = merge(local.common_tags, {
        Service = "aurora"
        Type = "logs"
    })
}

# Aurora DB Alarms
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
    alarm_name = "aurora-high-cpu"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "2"
    metric_name = "CPUUtilization"
    namespace = "AWS/RDS"
    period = "300"
    statistic = "Average"
    threshold = "80"
    alarm_description = "Aurora CPU Utilization above 80%"

    dimensions = {
      DBClusterIdentifier = var.aurora_cluster_arn
    }

    alarm_actions = [aws_sns_topic.banking_alerts.arn]
    tags = merge(local.common_tags, {
        Service = "aurora"
        Type = "alarm"
    })
}

# CloudWatch Log Group for WAF 
resource "aws_cloudwatch_log_group" "waf" {
    name = "/aws/waf"
    retention_in_days = 90
    tags = merge(local.common_tags, {
        Service = "WAF"
        Type = "Logs"
    })
}

# WAF Alarm for Blocked Requests
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
    alarm_name = "waf-blocked-requests"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "2"
    metric_name = "BlockedRequests"
    namespace = "AWS/WAFV2"
    period = "300"
    statistic = "Sum"
    threshold = "100"
    alarm_description = "WAF Blocked Requests exceeded threshold"

    dimensions = {
      WEBACL = var.web_acl_name
      Rule = "ALL"
      Region = "eu-west-2"
    }

    alarm_actions = [aws_sns_topic.banking_alerts.arn]
    tags = merge(local.common_tags, {
        Service = "WAF"
        Type = "alarms"
    })
}

# WAF Alarm for Allowed Requests
resource "aws_cloudwatch_metric_alarm" "waf_allowed_requests" {
    alarm_name = "waf-allowed-requests"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "2"
    metric_name = "AllowedRequests"
    namespace = "AWS/WAFV2"
    period = "300"
    statistic = "Sum"
    threshold = "100"
    alarm_description = "Unusual Spike in Allowed Requests"

    dimensions = {
      WEBACL = var.web_acl_name
      Rule = "ALL"
      Region = "eu-west-2"
    }

    alarm_actions = [aws_sns_topic.banking_alerts.arn]
    tags = merge(local.common_tags, {
        Service = "WAF"
        Type = "alarms"
    })
}

# CloudWatch Log Group for Macie
resource "aws_cloudwatch_log_group" "macie" {
    name = "/aws/macie"
    retention_in_days = 90
    tags = merge(local.common_tags, {
        Service = "Macie"
        Type = "Logs"
    })
}

# Macie Alarm for Sensitive Data Findings
resource "aws_cloudwatch_metric_alarm" "macie_findings" {
    alarm_name = "macie-sensitive-data-findings"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "SensitiveDataDiscovered"
    namespace = "AWS/Macie"
    period = "300"
    statistic = "Sum"
    threshold = "0"
    alarm_description = "Macie discovered sensitive data"

    dimensions = {
      ClassificationJobId = var.macie_classification_job_id
    }

    alarm_actions = [aws_sns_topic.banking_alerts.arn]
    tags = merge(local.common_tags, {
        Service = "Macie"
        Type = "alarms"
    })
}

# CloudWatch Log Group for Network Firewall
resource "aws_cloudwatch_log_group" "network_firewall" {
    name = "/aws/networkfirewall"
    retention_in_days = 90
    tags = merge(local.common_tags, {
        Service = "Network Firewall"
        Type = "Logs"
    })
}

# Network Firewall Alarm for Incoming Traffic
resource "aws_cloudwatch_metric_alarm" "network_firewall" {
    alarm_name = "high-network-firewall-activity"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "IncomingBytes"
    namespace = "AWS/NetworkFirewall"
    period = "300"
    statistic = "Sum"
    threshold = "1000000"
    alarm_description = "Triffers if incoming traffic exceeds threshold, indicating potential high activity"

    dimensions = {
      FirewallArn = var.network_firewall_arn
    }

    alarm_actions = [aws_sns_topic.banking_alerts.arn]
    tags = merge(local.common_tags, {
        Service = "Network Firewall"
        Type = "alarms"
    })
}

# CloudWatch Log Group for DynamoDB
resource "aws_cloudwatch_log_group" "dynamodb" {
    name = "/aws/dynamodb"
    retention_in_days = 90
    tags = merge(local.common_tags, {
        Service = "DynamoDB"
        Type = "Logs"
    })
}

# DynamoDB Alarm for Throttled Write Requests
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttled_writes" {
    alarm_name = "dynamodb-throttled-writes"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "WriteThrottleEvents"
    namespace = "AWS/DynamoDB"
    period = "300"
    statistic = "Sum"
    threshold = "0"
    alarm_description = "Triffers when there are throttled write requests on Global Table"

    dimensions = {
      TableName = var.dynamodb_table_name
    }

    alarm_actions = [aws_sns_topic.banking_alerts.arn]
    tags = merge(local.common_tags, {
        Service = "DynamoDB"
        Type = "alarms"
    })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "Lambda" {
    name = "/aws/Lambda"
    retention_in_days = 90
    tags = merge(local.common_tags, {
        Service = "Lambda"
        Type = "Logs"
    })
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
    name = "/aws/apigateway/banking-api"
    retention_in_days = 30
    tags = merge(local.common_tags, {
        Service = "API Gateway"
        Type = "Logs"
    })
}

# EventBridge Rule for Macie Findings
resource "aws_cloudwatch_event_rule" "macie_findings" {
    name        = "macie-findings-rule"
    description = "Capture Macie sensitive data findings"

    event_pattern = jsonencode({
        source = ["aws.macie"]
        detail-type = ["Macie Finding"]
        detail = {
            severity = {
            description = ["HIGH"]
            }
            type = ["SensitiveData:S3Object/Financial"]
        }
    })
}

# EventBridge Target (Lambda)
resource "aws_cloudwatch_event_target" "macie_lambda" {
    rule = aws_cloudwatch_event_rule.macie_findings.name
    target_id = "MacieToLambda"
    arn = var.macie_findings_arn
}

# EventBridge Rule for Macie Findings
resource "aws_cloudwatch_event_rule" "config_rules" {
    name        = "config-rule-changees"
    description = "Capture Config Rule Security Group Changes"

    event_pattern = jsonencode({
        source = ["aws.config"]
        detail-type = ["AWS Config Rule Compliance Change"]
        detail = {
            severity = {
            configRuleName = ["security-group-changes"]
            resourceType = ["AWS:EC2::SecurityGroup"]
            configRuleEvaluations = ["FAILED"]
            }
        }
    })      
}

# EventBridge Target (Lambda)
resource "aws_cloudwatch_event_target" "config_lambda" {
    rule = aws_cloudwatch_event_rule.config_rules.name
    target_id = "ConfigRulesLambda"
    arn = var.config_rules_arn
}
