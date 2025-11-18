variable "rule_name" {
  type        = string
  description = "Name of the EventBridge rule"
}

variable "rule_description" {
  type        = string
  description = "Description of the EventBridge rule"
  default     = ""
}

variable "prefix" {
  type        = string
  description = "Prefix to add to the rule name"
  default     = ""
}

variable "eventbus" {
  type        = string
  description = "Name of the EventBridge event bus (use 'default' for the default bus)"
  default     = "default"
}

variable "event_pattern" {
  type        = string
  description = "Event pattern in JSON format (required if schedule_expression is not set)"
  default     = null
}

variable "schedule_expression" {
  type        = string
  description = "Cron or rate expression for scheduled events (required if event_pattern is not set)"
  default     = null
}

variable "enabled" {
  type        = bool
  description = "Whether the rule is enabled"
  default     = true
}

variable "queue" {
  type        = string
  description = "Name of the target SQS queue"
}

variable "target_id" {
  type        = string
  description = "Unique identifier for the target (auto-generated if not provided)"
  default     = ""
}

variable "role_arn" {
  type        = string
  description = "IAM role ARN for EventBridge to assume (optional)"
  default     = null
}

variable "sqs_message_group_id" {
  type        = string
  description = "Message group ID for FIFO SQS queues"
  default     = null
}

variable "dead_letter_arn" {
  type        = string
  description = "ARN of SQS queue for failed events"
  default     = null
}

variable "input_transformer" {
  type = object({
    input_paths    = optional(map(string))
    input_template = string
  })
  description = "Transform input before sending to SQS"
  default     = null
}

variable "retry_policy" {
  type = object({
    maximum_event_age_in_seconds = optional(number)
    maximum_retry_attempts       = optional(number)
  })
  description = "Retry configuration for failed event deliveries"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to the rule"
  default     = {}
}
