data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
    name = "global-banking-web-acl"
    description = "Web ACL for Banking Application"
    scope = "REGIONAL"

    default_action {
      allow {}
    }

    # Rate Limiting
    rule {
        name = "RateLimit"
        priority = 1

        statement {
          rate_based_statement {
            limit = 2000
            aggregate_key_type = "IP"
          }
        }

        action {
          block {}
        }

        visibility_config {
          cloudwatch_metrics_enabled = true
          metric_name = "RateLimitMetric"
          sampled_requests_enabled = true
        }
    }

    # Prevent SQL Injection
    rule {
        name = "SQLInjectionRule"
        priority = 2

        statement {
          sqli_match_statement {
            field_to_match {
                uri_path {}
            }
            text_transformation {
              priority = 1
              type = "URL_DECODE"
            }
            text_transformation {
              priority = 2
              type = "HTML_ENTITY_DECODE"
            }
          }
        }

        action {
          block {}
        }

        visibility_config {
          cloudwatch_metrics_enabled = true
          metric_name = "SQLInjectionMetric"
          sampled_requests_enabled = true
        }
    }

    # Geographic Restrictions
    rule {
        name = "GeoBlockRule"
        priority = 3

        statement {
            geo_match_statement {
                country_codes = ["BD", "IR", "CU"] # Random Countries to block
            }
        }

        action {
          block {}
        }

        visibility_config {
            cloudwatch_metrics_enabled = true
            metric_name = "GeoBlockMetric"
            sampled_requests_enabled = true
        }
    }

    visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name = "GlobalInsuranceWAFMetrics"
        sampled_requests_enabled = true 
    }
}

# WAF Association with ALB
resource "aws_wafv2_web_acl_association" "main" {
	resource_arn = var.alb_arn
	web_acl_arn = aws_wafv2_web_acl.main.arn
}

# Shield Advanced
resource "aws_shield_protection" "alb" {
    name = "global-banking-shield-protection"
    resource_arn = var.alb_arn

    tags = merge(local.common_tags, {
        Name = "ALB"
    })
}

# Network Firewall
resource "aws_networkfirewall_firewall" "main" {
    name = "global-banking-network-firewall"
    firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
    vpc_id = var.security_vpc_id

   	dynamic "subnet_mapping" {
		for_each = var.security_subnet_ids
		content {
			subnet_id = subnet_mapping.value
		}
	}
	tags = merge(local.common_tags, {
		Name =  "Network Firewall"
	})
}

resource "aws_networkfirewall_firewall_policy" "main" {
	name = "global-banking-firewall-policy"

	firewall_policy {
		stateless_default_actions = ["aws:forward_to_sfe"]
		stateless_fragment_default_actions = ["aws:forward_to_sfe"]
		
		stateful_rule_group_reference {
			resource_arn = aws_networkfirewall_rule_group.banking_protocols.arn
		}

		stateful_rule_group_reference {
			resource_arn = aws_networkfirewall_rule_group.threat_prevention.arn
		}
	}
	
	tags = local.common_tags
}

# Banking-Specific Protocols
resource "aws_networkfirewall_rule_group" "banking_protocols" {
	capacity = 100
	name = "banking-protocols"
	type = "STATEFUL"

	rule_group {
		rules_source {
			dynamic "stateful_rule" {
                for_each = var.swift_endpoints
				content {
                    action = "PASS"
                    header {
                        destination = stateful_rule.value
                        destination_port = "443"
                        protocol = "TCP"
                        direction = "FORWARD"
                        source = var.production_vpc_cidr
                        source_port = "ANY"
                    }
                    rule_option {
					keyword = "sid:1"
				    }
                }
                
				
			}

			dynamic "stateful_rule" {
                for_each = var.payment_gateway_endpoints
                content{
                    action = "PASS"
                    header {
                        destination = stateful_rule.value
                        destination_port = "443"
                        protocol = "TCP"
                        direction = "FORWARD"
                        source = var.production_vpc_cidr
                        source_port = "ANY"
                    }
                    rule_option {
                        keyword = "sid:2"
                    }
                }
				
			}	
		}
	}
	tags = local.common_tags
}

# Threat Prevention Rules
resource "aws_networkfirewall_rule_group" "threat_prevention" {
	capacity = 100
	name = "threat-prevention"
	type = "STATEFUL"

	rule_group {
		rules_source {
			rules_string = <<EOF
			# Block known malicious IPs
			drop tcp $EXTERNAL_NET any -> $HOME_NET any (msg:"Suspicious Banking Transaction Pattern"; flow:established; content:"POST"; http_uri; pcre:"/amount=[0-9]{6,}/"; sid: 1000001;)

			# Detect SQL Injection
            alert tcp $EXTERNAL_NET any -> $HOME_NET any (msg:"SQL Injection Attempt"; flow:established; content:"UNION"; nocase; content:"SELECT"; nocase; sid:1000002;)
        
            # Detect Unusual Access Patterns
            alert tcp any any -> $HOME_NET any (msg:"Multiple Failed Login Attempts"; flow:established; threshold:type both,track by_src,count 5,seconds 30; sid:1000003;)
            EOF
		}
	}
}

# Enable CloudWatch Logging
resource "aws_networkfirewall_logging_configuration" "main" {
	firewall_arn = aws_networkfirewall_firewall.main.arn
	logging_configuration {
		log_destination_config {
			log_destination = {
                logGroup = var.firewall_logs_name
			}
			log_destination_type = "CloudWatchLogs"
			log_type            = "ALERT"
		}
	}
}

# CloudTrail
resource "aws_cloudtrail" "main" {
    name = "global-banking-cloudtrail"
    s3_bucket_name = var.cloudtrail_bucket_id
    include_global_service_events = true
    is_multi_region_trail = true
    enable_logging = true
    kms_key_id = aws_kms_key.database.arn

	depends_on = [ 
		aws_s3_bucket_policy.cloudtrail_policy,
		aws_kms_key.database
	]
}

# GuardDuty
resource "aws_guardduty_detector" "main" {
    enable = true
}

# Security Hub
resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "pci" {
    standards_arn = "arn:aws:securityhub:eu-west-2::standards/pci-dss/v/3.2.1"
    depends_on = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "cis" {
    standards_arn = "arn:aws:securityhub:eu-west-2::standards/cis-aws-foundations-benchmark/v/3.0.0"
    depends_on = [aws_securityhub_account.main]
}

# AWS Config
resource "aws_config_configuration_recorder" "main" {
    name = "global-banking-config-recorder"
    role_arn = aws_iam_role.config.arn

    recording_group {
      all_supported = true
      include_global_resource_types = true
    }
}

resource "aws_config_configuration_recorder_status" "main" {
    name = aws_config_configuration_recorder.main.name
    is_enabled = true
    depends_on = [aws_config_configuration_recorder.main, aws_config_delivery_channel.main]
}

resource "aws_config_delivery_channel" "main" {
    name = "global-banking-delivery-channel"
    s3_bucket_name = var.audit_reports_bucket_name
}

# Config Rule Lambda SG Change
resource "aws_config_rule" "sg_changes" {
    name = "sg-changes"

    source {
        owner = "AWS"
        source_identifier = "INCOMING_SSH_DISABLED"
    }

    scope {
    compliance_resource_types = ["AWS::EC2::SecurityGroup"]
    }
}

# Macie Configuration
resource "aws_macie2_account" "global_bank" {
    finding_publishing_frequency = "FIFTEEN_MINUTES"
    status = "ENABLED"
}

# Enable Macie for S3 Bucket classification
resource "aws_macie2_classification_job" "s3_sensitive_data" {
    name = "insurance-data-classifcation"
    job_type = "SCHEDULED"
    job_status = "RUNNING"

    s3_job_definition {
      bucket_definitions {
            account_id = data.aws_caller_identity.current.account_id
		    buckets = local.monitored_buckets
        }
    }

    schedule_frequency {
      weekly_schedule = "MONDAY"
    }

    tags = merge(local.common_tags, {
        Service = "Macie"
        Type = "classification-job"
    })
}

