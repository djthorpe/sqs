
# SQS Queue Outputs
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

# Schema Information
output "registered_schemas" {
  description = "List of registered event schemas"
  value       = keys(local.schemas)
}
