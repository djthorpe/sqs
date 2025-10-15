
# SQS Queue Outputs
output "source_queue_url" {
  description = "URL of the source SQS queue"
  value       = module.sqs.ids["source"]
}

output "source_queue_arn" {
  description = "ARN of the source SQS queue"
  value       = module.sqs.arns["source"]
}

output "target_queue_url" {
  description = "URL of the target SQS queue"
  value       = module.sqs.ids["target"]
}

output "target_queue_arn" {
  description = "ARN of the target SQS queue"
  value       = module.sqs.arns["target"]
}

# EventBridge Outputs
output "event_bus_name" {
  description = "Name of the EventBridge event bus"
  value       = module.eventbridge.name
}

output "event_bus_arn" {
  description = "ARN of the EventBridge event bus"
  value       = module.eventbridge.arn
}

# Pipe and Rule Outputs
output "pipe_name" {
  description = "Name of the EventBridge pipe (SQS to EventBridge)"
  value       = module.sqs_to_eventbridge.pipe_name
}

output "rule_name" {
  description = "Name of the EventBridge rule (EventBridge to SQS)"
  value       = module.eventbridge_to_sqs.rule_name
}

# Schema Information
output "registered_schemas" {
  description = "List of registered event schemas"
  value       = keys(local.schemas)
}
