output "ids" {
  description = "Map of queue names to their IDs (URLs)"
  value       = { for k, v in aws_sqs_queue.queue : k => v.id }
}

output "arns" {
  description = "Map of queue names to their ARNs"
  value       = { for k, v in aws_sqs_queue.queue : k => v.arn }
}

output "names" {
  description = "Map of queue names to their full names (with prefix)"
  value       = { for k, v in aws_sqs_queue.queue : k => v.name }
}

output "deadletter_ids" {
  description = "Map of queue names to their dead letter queue IDs (URLs)"
  value       = { for k, v in aws_sqs_queue.deadletter : k => v.id }
}

output "deadletter_arns" {
  description = "Map of queue names to their dead letter queue ARNs"
  value       = { for k, v in aws_sqs_queue.deadletter : k => v.arn }
}

output "deadletter_names" {
  description = "Map of queue names to their dead letter queue names (with prefix)"
  value       = { for k, v in aws_sqs_queue.deadletter : k => v.name }
}
