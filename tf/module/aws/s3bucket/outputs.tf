output "ids" {
  description = "Map of bucket names to their IDs"
  value       = { for k, v in aws_s3_bucket.bucket : k => v.id }
}

output "arns" {
  description = "Map of bucket names to their ARNs"
  value       = { for k, v in aws_s3_bucket.bucket : k => v.arn }
}

output "names" {
  description = "Map of bucket names to their full names (with prefix)"
  value       = { for k, v in aws_s3_bucket.bucket : k => v.bucket }
}
