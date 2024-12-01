output "alb_arn" {
  value = aws_lb.production.arn
}

output "lambda_sg_id" {
  value = aws_security_group.lambda.id
}

output "macie_findings_arn" {
  value = aws_lambda_function.macie_findings.arn
}

output "fraud_detection_invoke_arn" {
  value = aws_lambda_function.fraud_detection.invoke_arn
}

output "config_rules_arn" {
  value = aws_lambda_function.config_rules.arn
}