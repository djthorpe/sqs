# AWS S3 Bucket Module

This Terraform module creates one or more S3 buckets with configurable lifecycle rules.

## Features

- Creates multiple S3 buckets with an optional common prefix
- Optional prefix (if empty, bucket names are used as-is without a leading hyphen)
- Simple lifecycle rules applied to all buckets
- Support for storage class transitions and expiration
- Custom tagging support
- Force destroy enabled for easy cleanup

## Usage

### Basic Example

```hcl
module "s3_buckets" {
  source = "./tf/module/aws/s3bucket"
  
  buckets = ["logs", "data", "backups"]
  prefix  = "myapp-prod"
}
```

This creates three buckets:

- `myapp-prod-logs`
- `myapp-prod-data`
- `myapp-prod-backups`

### Example without Prefix

```hcl
module "s3_buckets" {
  source = "./tf/module/aws/s3bucket"
  
  buckets = ["my-bucket-name", "another-bucket"]
  prefix  = ""
}
```

This creates two buckets:

- `my-bucket-name`
- `another-bucket`

### Example with Lifecycle Configuration and Tags

```hcl
module "s3_buckets" {
  source = "./tf/module/aws/s3bucket"
  
  buckets = ["logs", "data"]
  prefix  = "myapp-prod"
  
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
  
  expiration_days = 90
  
  transitions = [
    {
      days          = 30
      storage_class = "STANDARD_IA"
    },
    {
      days          = 60
      storage_class = "GLACIER"
    }
  ]
}
```

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `buckets` | `list(string)` | List of bucket names to create | - | Yes |
| `prefix` | `string` | Prefix to add to each bucket name. If empty, no prefix is added and no hyphen is prepended | `""` | No |
| `expiration_days` | `number` | Number of days until objects expire | `null` | No |
| `transitions` | `list(object)` | List of transition rules for storage classes (see below) | `[]` | No |
| `tags` | `map(string)` | Additional tags to apply to all buckets | `{}` | No |

### Transition Object

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `days` | `number` | Number of days after creation | Yes |
| `storage_class` | `string` | Storage class to transition to | Yes |

**Valid storage classes:**

- `STANDARD_IA` - Infrequent Access
- `ONEZONE_IA` - One Zone Infrequent Access
- `INTELLIGENT_TIERING`
- `GLACIER` - Glacier Flexible Retrieval
- `DEEP_ARCHIVE` - Glacier Deep Archive

## Outputs

| Name | Description |
|------|-------------|
| `ids` | Map of bucket names to their IDs |
| `arns` | Map of bucket names to their ARNs |
| `names` | Map of bucket names to their full names (with prefix) |

## Example Output Usage

```hcl
output "log_bucket_arn" {
  value = module.s3_buckets.arns["logs"]
}

output "all_bucket_names" {
  value = module.s3_buckets.names
}
```

## Notes

- All buckets are created with `force_destroy = true`, allowing them to be deleted even when they contain objects
- A single lifecycle rule is applied to all buckets created by the module
- Lifecycle configuration is only created if `expiration_days` or `transitions` are provided
- The lifecycle rule applies to all objects in the bucket (no prefix or tag filtering)
- For bucket-specific lifecycle configurations, create separate module instances
- If `prefix` is an empty string, bucket names are used exactly as provided without any prefix or hyphen
- All buckets receive a default tag `Name = "s3-{bucket_name}"` which is merged with any additional tags provided

## Requirements

- Terraform >= 1.0
- AWS Provider

## Module Files

- `main.tf` - Main resource definitions (S3 buckets and lifecycle configurations)
- `input.tf` - Input variable declarations
- `outputs.tf` - Output value definitions
- `README.md` - This documentation file
