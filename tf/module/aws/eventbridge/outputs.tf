output "name" {
  description = "Name of the event bus"
  value       = aws_cloudwatch_event_bus.bus.name
}

output "arn" {
  description = "ARN of the event bus"
  value       = aws_cloudwatch_event_bus.bus.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group (null if logging not enabled)"
  value       = var.log_retention_days > 0 ? aws_cloudwatch_log_group.eventbridge[0].name : null
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group (null if logging not enabled)"
  value       = var.log_retention_days > 0 ? aws_cloudwatch_log_group.eventbridge[0].arn : null
}

output "archive_name" {
  description = "Name of the event archive (null if archive not enabled)"
  value       = var.archive_retention_days > 0 ? aws_cloudwatch_event_archive.archive[0].name : null
}
