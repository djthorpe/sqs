output "pipe_name" {
  description = "Name of the EventBridge pipe"
  value       = aws_pipes_pipe.sqs_to_eventbridge.name
}

output "pipe_arn" {
  description = "ARN of the EventBridge pipe"
  value       = aws_pipes_pipe.sqs_to_eventbridge.arn
}

output "pipe_id" {
  description = "ID of the EventBridge pipe"
  value       = aws_pipes_pipe.sqs_to_eventbridge.id
}

output "role_arn" {
  description = "ARN of the IAM role used by the pipe"
  value       = aws_iam_role.pipe.arn
}
