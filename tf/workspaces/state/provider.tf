terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.16.0"
    }
  }
}

// Configure the AWS Provider
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Provider = "terraform"
      Env      = var.env
      Service  = var.service
      Team     = var.team
    }
  }
}

// Set AWS information
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}
