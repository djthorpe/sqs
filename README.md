# SQS Project

AWS SQS infrastructure and command-line tools for managing queues and messages.

## Project Structure

```
.
├── cmd/
│   ├── publish/      # Command to publish messages to SQS
│   └── subscribe/    # Command to subscribe to and process SQS messages
├── tf/
│   ├── module/
│   │   └── aws/
│   │       ├── s3bucket/  # Terraform module for S3 buckets
│   │       └── sqs/       # Terraform module for SQS queues
│   └── workspaces/
│       ├── root/     # Root infrastructure workspace
│       └── state/    # Terraform state management workspace
├── bin/              # Built binaries (gitignored)
├── go.mod
└── Makefile
```

## Quick Start

### Build Commands

```bash
# Build all commands
make build

# Build individual commands
make build-publish
make build-subscribe

# Clean build artifacts
make clean
```

### Usage Examples

#### Publish a message to a queue

```bash
./bin/publish -queue "https://sqs.region.amazonaws.com/account/queue-name" -message "Hello, SQS!"
```

#### Subscribe to messages

```bash
./bin/subscribe -queue "https://sqs.region.amazonaws.com/account/queue-name" -workers 5 -delete
```

See individual command READMEs for more details:

- [cmd/publish/README.md](cmd/publish/README.md)
- [cmd/subscribe/README.md](cmd/subscribe/README.md)

## Terraform Modules

### SQS Module

Creates one or more SQS queues (standard or FIFO) with optional dead letter queues.

**Standard Queue:**

```hcl
module "sqs_queues" {
  source = "./tf/module/aws/sqs"
  
  queues = ["orders", "events"]
  prefix = "myapp-prod"
  
  message_retention_hours            = 96   # 4 days
  deadletter_message_retention_hours = 336  # 14 days
  max_receive_count                  = 3
}
```

**FIFO Queue (with strict ordering):**

```hcl
module "sqs_fifo_queues" {
  source = "./tf/module/aws/sqs"
  
  queues = ["transactions", "orders"]
  prefix = "myapp-prod"
  
  fifo_queue                  = true
  content_based_deduplication = true
  
  deadletter_message_retention_hours = 336
}
```

See [tf/module/aws/sqs/README.md](tf/module/aws/sqs/README.md) for full documentation.

### S3 Bucket Module

Creates one or more S3 buckets with optional lifecycle rules.

```hcl
module "s3_buckets" {
  source = "./tf/module/aws/s3bucket"
  
  buckets = ["logs", "data"]
  prefix  = "myapp-prod"
  
  expiration_days = 90
  transitions = [
    {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  ]
}
```

See [tf/module/aws/s3bucket/README.md](tf/module/aws/s3bucket/README.md) for full documentation.

## Terraform Workspaces

### Deploy Infrastructure

```bash
# Create S3 bucket for Terraform state
make tfstate

# Plan infrastructure changes
make tfplan

# Apply infrastructure changes
make tfapply
```

### Configuration

Environment variables:

- `AWS_REGION` - AWS region (default: eu-central-1)
- `ENV` - Environment: prd, stg, or dev (default: dev)
- `TEAM` - Team name (default: fabric)
- `SERVICE` - Service name (default: sqs)

Example:

```bash
ENV=prod TEAM=engineering make tfapply
```

## Requirements

- Go 1.24.2+
- Terraform 1.0+
- AWS credentials configured

## AWS Permissions

### For Commands

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:*:*:*"
    }
  ]
}
```

### For Terraform

Requires permissions to create and manage:

- SQS queues
- S3 buckets
- IAM policies (if applicable)

## Commands

### publish

Publishes messages to an SQS queue.

```bash
./bin/publish -queue "<queue-url>" -message "Hello, SQS!"
```

Key features:

- Supports standard and FIFO queues
- JSON message support
- Message deduplication for FIFO queues

### subscribe

Subscribes to an SQS queue and processes messages using concurrent workers.

```bash
./bin/subscribe -queue "<queue-url>" -workers 5 -delete
```

Key features:

- Concurrent message processing with worker pool
- Long polling for efficiency
- Graceful shutdown
- Optional auto-delete after processing

## Development

```bash
# Install dependencies
go mod download

# Run tests
go test ./...

# Format code
go fmt ./...
```

## License

[Add your license here]
