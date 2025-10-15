variable "queues" {
  type        = list(string)
  description = "List of queue names to create"
}

variable "prefix" {
  type        = string
  description = "Prefix to add to each queue name"
  default     = ""
}

variable "delay_hours" {
  type        = number
  description = "The time in hours that the delivery of all messages in the queue will be delayed"
  default     = 0
}

variable "max_message_size" {
  type        = number
  description = "The limit of how many bytes a message can contain before Amazon SQS rejects it"
  default     = 262144
}

variable "message_retention_hours" {
  type        = number
  description = "The number of hours Amazon SQS retains a message"
  default     = 96
}

variable "receive_wait_time_seconds" {
  type        = number
  description = "The time in seconds for which a ReceiveMessage call will wait for a message to arrive (long polling)"
  default     = 0
}

variable "visibility_timeout_hours" {
  type        = number
  description = "The visibility timeout for the queue in hours"
  default     = 0.5
}

variable "deadletter_message_retention_hours" {
  type        = number
  description = "The number of hours Amazon SQS retains a message in the dead letter queue. Set to 0 to disable dead letter queue creation"
  default     = 0
}

variable "max_receive_count" {
  type        = number
  description = "The number of times a message is delivered to the source queue before being moved to the dead-letter queue"
  default     = 3
}

variable "fifo_queue" {
  type        = bool
  description = "Whether to create FIFO queues. FIFO queues have strict ordering and exactly-once processing"
  default     = false
}

variable "content_based_deduplication" {
  type        = bool
  description = "Enable content-based deduplication for FIFO queues. Only applies when fifo_queue is true"
  default     = false
}

variable "deduplication_scope" {
  type        = string
  description = "Specifies whether message deduplication occurs at the message group or queue level. Valid values: messageGroup, queue. Only applies to FIFO queues"
  default     = "queue"
  validation {
    condition     = contains(["messageGroup", "queue"], var.deduplication_scope)
    error_message = "The deduplication_scope value must be either 'messageGroup' or 'queue'."
  }
}

variable "fifo_throughput_limit" {
  type        = string
  description = "Specifies whether the FIFO queue throughput limit is per queue or per message group. Valid values: perQueue, perMessageGroupId. Only applies to FIFO queues"
  default     = "perQueue"
  validation {
    condition     = contains(["perQueue", "perMessageGroupId"], var.fifo_throughput_limit)
    error_message = "The fifo_throughput_limit value must be either 'perQueue' or 'perMessageGroupId'."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to the queue(s)"
  default     = {}
}
