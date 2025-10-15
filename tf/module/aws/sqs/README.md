# AWS SQS Queue Module

This Terraform module creates one or more SQS queues with optional dead letter queues.

## Features

- Creates multiple SQS queues with an optional common prefix
- Optional prefix (if empty, queue names are used as-is without a leading hyphen)
- Configurable queue settings (delay, message size, retention, timeouts)
- Optional dead letter queue (DLQ) for each queue
- Custom tagging support

## Usage

### Basic Example

```hcl
module "sqs_queues" {
  source = "./tf/module/aws/sqs"
  
  queues = ["orders", "notifications", "events"]
  prefix = "myapp-prod"
}
```

This creates three queues:

- `myapp-prod-orders`
- `myapp-prod-notifications`
- `myapp-prod-events`

### Example without Prefix

```hcl
module "sqs_queues" {
  source = "./tf/module/aws/sqs"
  
  queues = ["my-queue-name", "another-queue"]
  prefix = ""
}
```

This creates two queues:

- `my-queue-name`
- `another-queue`

### Example with Dead Letter Queue

```hcl
module "sqs_queues" {
  source = "./tf/module/aws/sqs"
  
  queues = ["orders", "events"]
  prefix = "myapp-prod"
  
  deadletter_message_retention_hours = 336  # 14 days
  max_receive_count                  = 3
  
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

This creates:

- Main queues: `myapp-prod-orders`, `myapp-prod-events`
- Dead letter queues: `myapp-prod-orders-dlq`, `myapp-prod-events-dlq`

### Example with FIFO Queue

```hcl
module "sqs_fifo_queues" {
  source = "./tf/module/aws/sqs"
  
  queues = ["orders", "transactions"]
  prefix = "myapp-prod"
  
  fifo_queue                  = true
  content_based_deduplication = true
  deduplication_scope         = "queue"
  fifo_throughput_limit       = "perQueue"
  
  deadletter_message_retention_hours = 336
  max_receive_count                  = 3
  
  tags = {
    Environment = "production"
    Type        = "fifo"
  }
}
```

This creates:

- Main FIFO queues: `myapp-prod-orders.fifo`, `myapp-prod-transactions.fifo`
- Dead letter FIFO queues: `myapp-prod-orders-dlq.fifo`, `myapp-prod-transactions-dlq.fifo`

### Example with Custom Settings

```hcl
module "sqs_queues" {
  source = "./tf/module/aws/sqs"
  
  queues = ["processing"]
  prefix = "myapp"
  
  delay_hours                = 0.001  # ~5 seconds
  max_message_size           = 262144
  message_retention_hours    = 24     # 1 day
  receive_wait_time_seconds  = 10     # Long polling
  visibility_timeout_hours   = 0.017  # ~1 minute
  
  deadletter_message_retention_hours = 336  # 14 days (enables DLQ)
  max_receive_count                  = 5
}
```

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `queues` | `list(string)` | List of queue names to create | - | Yes |
| `prefix` | `string` | Prefix to add to each queue name. If empty, no prefix is added and no hyphen is prepended | `""` | No |
| `delay_hours` | `number` | The time in hours that the delivery of all messages in the queue will be delayed | `0` | No |
| `max_message_size` | `number` | The limit of how many bytes a message can contain (1024-262144) | `262144` | No |
| `message_retention_hours` | `number` | The number of hours Amazon SQS retains a message | `96` (4 days) | No |
| `receive_wait_time_seconds` | `number` | The time in seconds for which a ReceiveMessage call will wait for a message (long polling, 0-20) | `0` | No |
| `visibility_timeout_hours` | `number` | The visibility timeout for the queue in hours | `0.5` (30 min) | No |
| `deadletter_message_retention_hours` | `number` | The number of hours Amazon SQS retains a message in the dead letter queue. Set to 0 to disable DLQ creation | `0` | No |
| `max_receive_count` | `number` | The number of times a message is delivered before being moved to the dead-letter queue | `3` | No |
| `fifo_queue` | `bool` | Whether to create FIFO queues with strict ordering and exactly-once processing | `false` | No |
| `content_based_deduplication` | `bool` | Enable content-based deduplication for FIFO queues (only applies when fifo_queue is true) | `false` | No |
| `deduplication_scope` | `string` | Message deduplication scope for FIFO queues: `messageGroup` or `queue` | `"queue"` | No |
| `fifo_throughput_limit` | `string` | FIFO throughput limit: `perQueue` or `perMessageGroupId` | `"perQueue"` | No |
| `tags` | `map(string)` | Additional tags to apply to all queues | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| `ids` | Map of queue names to their IDs (URLs) |
| `arns` | Map of queue names to their ARNs |
| `names` | Map of queue names to their full names (with prefix) |
| `deadletter_ids` | Map of queue names to their dead letter queue IDs (URLs) |
| `deadletter_arns` | Map of queue names to their dead letter queue ARNs |
| `deadletter_names` | Map of queue names to their dead letter queue names (with prefix) |

## Example Output Usage

```hcl
output "orders_queue_url" {
  value = module.sqs_queues.ids["orders"]
}

output "all_queue_arns" {
  value = module.sqs_queues.arns
}

output "orders_dlq_arn" {
  value = module.sqs_queues.deadletter_arns["orders"]
}
```

## FIFO Queue Features

FIFO (First-In-First-Out) queues provide:

- **Strict ordering**: Messages are processed in the exact order they're sent
- **Exactly-once processing**: No duplicate messages
- **Message groups**: Process related messages in order while allowing parallel processing of different groups
- **Deduplication**: Automatic deduplication based on message content or deduplication ID

### FIFO vs Standard Queues

| Feature | Standard Queue | FIFO Queue |
|---------|---------------|------------|
| Ordering | Best-effort | Strict FIFO |
| Delivery | At-least-once | Exactly-once |
| Throughput | Unlimited | 300 msg/sec (3,000 with batching) |
| Naming | Any name | Must end with `.fifo` |
| Deduplication | Not supported | Supported |
| Use case | High throughput | Critical ordering |

### FIFO Configuration Options

- **`content_based_deduplication`**: When true, SQS uses SHA-256 hash of message body for deduplication. When false, you must provide a deduplication ID with each message.
- **`deduplication_scope`**:
  - `queue`: Deduplication applies across the entire queue
  - `messageGroup`: Deduplication applies per message group ID
- **`fifo_throughput_limit`**:
  - `perQueue`: 300 messages per second per queue (3,000 with batching)
  - `perMessageGroupId`: 300 messages per second per message group

## Notes

- Queue IDs in SQS are actually the queue URLs
- If `prefix` is an empty string, queue names are used exactly as provided without any prefix or hyphen
- FIFO queues automatically have `.fifo` suffix added to their names
- Dead letter queues are automatically created with a `-dlq` suffix (or `-dlq.fifo` for FIFO) when `deadletter_message_retention_hours > 0`
- Set `deadletter_message_retention_hours = 0` to disable dead letter queue creation (default)
- All queues receive a default tag `Name = "sqs-{queue_name}"` which is merged with any additional tags provided
- Message retention defaults to 96 hours (4 days) for main queues
- Time values are specified in hours (fractional values allowed for sub-hour durations)
- `receive_wait_time_seconds` remains in seconds as it's typically a small value for long polling (0-20 seconds)
- FIFO queue settings are only applied when `fifo_queue = true`
- For queue-specific settings, create separate module instances

## Requirements

- Terraform >= 1.0
- AWS Provider

## Module Files

- `main.tf` - Main resource definitions (SQS queues and redrive policies)
- `input.tf` - Input variable declarations
- `outputs.tf` - Output value definitions
- `README.md` - This documentation file
