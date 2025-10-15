variable "name" {
  type        = string
  description = "Name of the event bus to create"
}

variable "prefix" {
  type        = string
  description = "Prefix to add to the event bus name"
  default     = ""
}

variable "schemas" {
  type = map(object({
    type        = string
    description = optional(string, "")
    content     = string
  }))
  description = "Map of schema name to schema definition (type: OpenApi3 or JSONSchemaDraft4)"
  default     = {}

  validation {
    condition = alltrue([
      for schema in var.schemas : contains(["OpenApi3", "JSONSchemaDraft4"], schema.type)
    ])
    error_message = "Schema type must be either 'OpenApi3' or 'JSONSchemaDraft4'"
  }
}

variable "enable_schema_discovery" {
  type        = bool
  description = "Enable automatic schema discovery for events on this bus"
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain CloudWatch logs. Set to 0 to disable logging."
  default     = 0

  validation {
    condition     = var.log_retention_days >= 0
    error_message = "log_retention_days must be greater than or equal to 0"
  }
}

variable "log_level" {
  type        = string
  description = "Log level for EventBridge logging. Valid values: OFF, ERROR, INFO, TRACE"
  default     = "INFO"

  validation {
    condition     = contains(["OFF", "ERROR", "INFO", "TRACE"], var.log_level)
    error_message = "log_level must be one of: OFF, ERROR, INFO, TRACE"
  }
}

variable "log_include_detail" {
  type        = string
  description = "Whether to include full event detail in logs. Valid values: NONE, FULL"
  default     = "FULL"

  validation {
    condition     = contains(["NONE", "FULL"], var.log_include_detail)
    error_message = "log_include_detail must be either NONE or FULL"
  }
}

variable "archive_retention_days" {
  type        = number
  description = "Number of days to retain event archive. Set to 0 to disable event archive."
  default     = 0

  validation {
    condition     = var.archive_retention_days >= 0
    error_message = "archive_retention_days must be greater than or equal to 0"
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
