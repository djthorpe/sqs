terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.16.0"
    }
  }

  backend "s3" {
    // key, region and bucket are passed as command-line arguments
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
data "aws_region" "current" {}

locals {
  aws_account = data.aws_caller_identity.current.account_id
  aws_region  = data.aws_region.current.region
}
