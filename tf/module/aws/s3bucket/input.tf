variable "buckets" {
  type        = list(string)
  description = "List of bucket names to create"
}

variable "prefix" {
  type        = string
  description = "Prefix to add to each bucket name"
  default     = ""
}

variable "expiration_days" {
  type        = number
  description = "Number of days until objects expire"
  default     = null
}

variable "transitions" {
  type = list(object({
    days          = number
    storage_class = string
  }))
  description = "List of transition rules for storage classes"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to the bucket(s)."
  default     = {}
}
