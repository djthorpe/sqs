variable "name" {
  type        = string
  description = "Name of the S3 to EventBridge integration"
}

variable "prefix" {
  type        = string
  description = "Prefix to add to resource names"
  default     = ""
}

variable "bucket" {
  type        = string
  description = "Name of the S3 bucket to monitor for events"
}

variable "eventbus" {
  type        = string
  description = "Name of the EventBridge event bus (use 'default' for the default bus)"
}

variable "event_types" {
  type        = list(string)
  description = "List of S3 event types to monitor"
  default = [
    "Object Created",
    "Object Deleted",
  ]
}

variable "filter_prefix" {
  type        = string
  description = "Object key prefix to filter events (optional)"
  default     = null
}

variable "filter_suffix" {
  type        = string
  description = "Object key suffix to filter events (optional)"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources"
  default     = {}
}
