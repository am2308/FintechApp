output "network_firewall_logs_name" {
    value = aws_cloudwatch_log_group.network_firewall.name
}

output "sns_topic_arn" {
    value = aws_sns_topic.banking_alerts.arn
}

output "api_log_group_arn" {
    value = aws_cloudwatch_log_group.api_gateway.arn
}

output "cloudwatch_event_rule_macie_findings_arn" {
    value = aws_cloudwatch_event_rule.macie_findings.arn
}
