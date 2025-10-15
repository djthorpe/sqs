
variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "env" {
  type        = string
  description = "prd, stg or dev"
  validation {
    condition     = contains(["prd", "stg", "dev"], var.env)
    error_message = "The env value must be one of: prd, stg, dev."
  }
}

variable "team" {
  type        = string
  description = "Team Name"
}

variable "service" {
  type        = string
  description = "Service Name"
}
