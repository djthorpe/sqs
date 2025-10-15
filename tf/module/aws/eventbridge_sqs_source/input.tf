variable "name" {
  type        = string
  description = "Name of the pipe"
}

variable "prefix" {
  type        = string
  description = "Prefix to add to resource names"
  default     = ""
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN of the source SQS queue"
}

variable "event_bus_arn" {
  type        = string
  description = "ARN of the target EventBridge event bus"
}

variable "detail_type" {
  type        = string
  description = "The detail-type for events sent to EventBridge"
}

variable "event_source" {
  type        = string
  description = "The source identifier for events sent to EventBridge"
}

variable "batch_size" {
  type        = number
  description = "Maximum number of messages to retrieve from SQS in a single batch (1-10000)"
  default     = 10

  validation {
    condition     = var.batch_size >= 1 && var.batch_size <= 10000
    error_message = "batch_size must be between 1 and 10000"
  }
}

variable "maximum_batching_window_seconds" {
  type        = number
  description = "Maximum amount of time in seconds to gather records before invoking the pipe (0-300)"
  default     = 0

  validation {
    condition     = var.maximum_batching_window_seconds >= 0 && var.maximum_batching_window_seconds <= 300
    error_message = "maximum_batching_window_seconds must be between 0 and 300"
  }
}

variable "filter_pattern" {
  type        = string
  description = "Event filter pattern in JSON format to filter messages from SQS"
  default     = null
}

variable "input_template" {
  type        = string
  description = "Input template to transform the message before sending to EventBridge"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources"
  default     = {}
}
