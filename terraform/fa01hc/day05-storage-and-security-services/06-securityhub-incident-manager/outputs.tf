output "event_rule_name" {
  description = "EventBridge rule that routes high and critical Security Hub findings."
  value       = aws_cloudwatch_event_rule.securityhub_high_severity.name
}

output "incident_topic_arn" {
  description = "SNS topic ARN used for Security Hub finding notifications."
  value       = aws_sns_topic.incidents.arn
}

output "response_plan_arn" {
  description = "Incident Manager response plan ARN."
  value       = aws_ssmincidents_response_plan.main.arn
}

output "securityhub_standard_arn" {
  description = "Security Hub standards subscription ARN."
  value       = aws_securityhub_standards_subscription.foundational.standards_arn
}
