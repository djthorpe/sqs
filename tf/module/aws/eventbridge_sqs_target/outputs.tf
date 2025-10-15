output "rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.rule.name
}

output "rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.rule.arn
}

output "rule_id" {
  description = "ID of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.rule.id
}

output "target_id" {
  description = "ID of the event target"
  value       = aws_cloudwatch_event_target.sqs.target_id
}
