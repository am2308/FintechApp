# SNS Topic for Alerts
resource "aws_sns_topic" "banking_alerts" {
  name = "global-banking-alerts"
  tags = merge(local.common_tags, {
    Name = "SNS Topic"
  })
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.banking_alerts.arn
  protocol  = "email"
  endpoint  = "mtalhazamanb@gmail.com"
}

