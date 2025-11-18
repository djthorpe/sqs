# AWS EventBridge SQS Target Module

This Terraform module creates an EventBridge rule that routes events to an SQS queue, with automatic IAM policy configuration.

## Features

- Creates EventBridge rules with event patterns or schedules
- Routes events to SQS queues (standard or FIFO)
- Automatically configures SQS queue policy for EventBridge access
- Supports FIFO queues with message group IDs
- Input transformation for customizing event payloads
- Dead letter queue configuration for failed events
- Retry policies for event delivery failures
- Custom tagging support

## Usage

### Basic Example - Event Pattern

```hcl
module "order_events_to_sqs" {
  source = "./tf/module/aws/eventbridge_sqs_target"
  
  rule_name        = "order-created"
  rule_description = "Route order creation events to SQS"
  
  event_pattern = jsonencode({
    source      = ["myapp.orders"]
    detail-type = ["Order Created"]
  })
  
  queue = "order-queue"
}
```

### Example with Custom Event Bus

```hcl
module "eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  event_buses = ["orders"]
  prefix      = "myapp"
}

module "sqs" {
  source = "./tf/module/aws/sqs"
  
  queues = ["order-processor"]
  prefix = "myapp"
}

module "order_events" {
  source = "./tf/module/aws/eventbridge_sqs_target"
  
  rule_name = "order-created"
  eventbus  = module.eventbridge.name
  prefix    = "myapp"
  
  event_pattern = jsonencode({
    source      = ["myapp.orders"]
    detail-type = ["Order Created"]
  })
  
  queue = module.sqs.names["order-processor"]
}
```

### Example with FIFO Queue

```hcl
module "transaction_events" {
  source = "./tf/module/aws/eventbridge_sqs_target"
  
  rule_name        = "transaction-completed"
  rule_description = "Route transactions to FIFO queue"
  
  event_pattern = jsonencode({
    source      = ["myapp.transactions"]
    detail-type = ["Transaction Completed"]
  })
  
  queue                = "transactions.fifo"
  sqs_message_group_id = "transactions"
```

### Example with Schedule Expression

```hcl
module "daily_report" {
  source = "./tf/module/aws/eventbridge_sqs_target"
  
  rule_name           = "daily-report-trigger"
  rule_description    = "Trigger daily report generation at midnight"
  schedule_expression = "cron(0 0 * * ? *)"
  
  queue = "report-queue"
}
```

### Example with Input Transformer

```hcl
module "user_signup_events" {
  source = "./tf/module/aws/eventbridge_sqs_target"
  
  rule_name = "user-signup"
  
  event_pattern = jsonencode({
    source      = ["myapp.users"]
    detail-type = ["User Signup"]
  })
  
  queue = "user-notifications"
  
  input_transformer = {
    input_paths = {
      userId    = "$.detail.userId"
      email     = "$.detail.email"
      timestamp = "$.time"
    }
    input_template = jsonencode({
      user_id   = "<userId>"
      email     = "<email>"
      timestamp = "<timestamp>"
      action    = "send_welcome_email"
    })
  }
}
```

### Example with Dead Letter Queue and Retry Policy

```hcl
module "critical_events" {
  source = "./tf/module/aws/eventbridge_sqs_target"
  
  rule_name        = "critical-alerts"
  rule_description = "Route critical alerts with retry and DLQ"
  
  event_pattern = jsonencode({
    source      = ["myapp.critical"]
    detail-type = ["Critical Alert"]
  })
  
  queue           = "critical-alerts"
  dead_letter_arn = "arn:aws:sqs:us-east-1:123456789012:critical-alerts-dlq"
  
  retry_policy = {
    maximum_event_age_in_seconds = 3600  # 1 hour
    maximum_retry_attempts       = 3
  }
}

### Complete Multi-Module Example

```hcl
# Create event buses
module "eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  event_buses = ["orders", "payments"]
  prefix      = "myapp"
  
  tags = {
    Environment = "production"
  }
}

# Create SQS queues
module "sqs" {
  source = "./tf/module/aws/sqs"
  
  queues                      = ["order-processor", "payment-processor"]
  prefix                      = "myapp"
  visibility_timeout_hours    = 1
  message_retention_hours     = 96  # 4 days
  receive_wait_time_seconds   = 20
  
  tags = {
    Environment = "production"
  }
}

# Route order events to SQS
module "order_events_to_sqs" {
  source = "./tf/module/aws/eventbridge_sqs_target"
  
  rule_name = "order-created"
  eventbus  = module.eventbridge.name
  prefix    = "myapp"
  
  event_pattern = jsonencode({
    source      = ["myapp.orders"]
    detail-type = ["Order Created", "Order Updated"]
  })
  
  queue = module.sqs.names["order-processor"]
}

# Route payment events to SQS
module "payment_events_to_sqs" {
  source = "./tf/module/aws/eventbridge_sqs_target"
  
  rule_name = "payment-processed"
  eventbus  = module.eventbridge.name
  prefix    = "myapp"
  
  event_pattern = jsonencode({
    source      = ["myapp.payments"]
    detail-type = ["Payment Processed"]
  })
  
  queue = module.sqs.names["payment-processor"]
}
```

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `rule_name` | `string` | Name of the EventBridge rule | - | Yes |
| `rule_description` | `string` | Description of the EventBridge rule | `""` | No |
| `prefix` | `string` | Prefix to add to the rule name | `""` | No |
| `eventbus` | `string` | Name of the EventBridge event bus | `"default"` | No |
| `event_pattern` | `string` | Event pattern in JSON format | `null` | No* |
| `schedule_expression` | `string` | Cron or rate expression for scheduled events | `null` | No* |
| `enabled` | `bool` | Whether the rule is enabled | `true` | No |
| `queue` | `string` | Name of the target SQS queue | - | Yes |
| `target_id` | `string` | Custom identifier for the EventBridge target | `""` | No |
| `role_arn` | `string` | IAM role for EventBridge to assume when invoking the target | `null` | No |
| `sqs_message_group_id` | `string` | FIFO queue message group ID | `null` | No |
| `dead_letter_arn` | `string` | ARN of SQS queue for failed events | `null` | No |
| `input_transformer` | `object` | Transform input before sending to SQS | `null` | No |
| `retry_policy` | `object` | Retry configuration for failed deliveries | `null` | No |
| `tags` | `map(string)` | Additional tags to apply to the rule | `{}` | No |

### Input Transformer Object

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `input_paths` | `map(string)` | Map of JSON path expressions to extract values | No |
| `input_template` | `string` | Template for the transformed payload | Yes |

### Retry Policy Object

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `maximum_event_age_in_seconds` | `number` | Maximum age of event (60-86400 seconds) | No |
| `maximum_retry_attempts` | `number` | Maximum retry attempts (0-185) | No |

## Event Pattern Examples

```json
{

### Match Multiple Detail Types

  "source": ["myapp.orders"],
  "detail-type": ["Order Created", "Order Updated", "Order Cancelled"]
}
```

### Match with Detail Filtering

```json
{
  "source": ["myapp.orders"],
  "detail-type": ["Order Placed"],
  "detail": {
    "status": ["confirmed"],
    "amount": [{"numeric": [">", 100]}]
  }
}
```

### Match from Multiple Sources

```json
{
  "source": ["myapp.orders", "myapp.payments"],
  "detail-type": ["Transaction Completed"]
}
```

## Schedule Expression Examples

### Cron Expressions

- `cron(0 12 * * ? *)` - Every day at noon UTC
- `cron(0 9 ? * MON-FRI *)` - Every weekday at 9 AM UTC
- `cron(0 0 1 * ? *)` - First day of every month at midnight UTC
- `cron(0/15 * * * ? *)` - Every 15 minutes

### Rate Expressions

- `rate(5 minutes)` - Every 5 minutes
- `rate(1 hour)` - Every hour
- `rate(7 days)` - Every 7 days

## IAM Permissions

This module automatically creates an SQS queue policy that allows EventBridge to send messages to the target queue. The policy:

- Grants `sqs:SendMessage` permission to the EventBridge service
- Scopes the permission to the specific rule ARN
- Follows the principle of least privilege

No additional IAM configuration is required unless you're using cross-account event routing.

## Notes

- Either `event_pattern` or `schedule_expression` must be specified, but not both
- For FIFO queues, set `sqs_message_group_id` to enable ordered processing
- Input transformers can reduce message size and standardize payloads
- Dead letter queues are useful for capturing and debugging failed events
- Retry policies help handle transient failures
- The module automatically handles IAM permissions for EventBridge to send to SQS
- Maximum of 300 rules per event bus
- Event patterns use content-based filtering

## Requirements

- Terraform >= 1.0
- AWS Provider >= 4.0

## Module Files

- `main.tf` - Main resource definitions (rule, target, SQS policy)
- `input.tf` - Input variable declarations
- `outputs.tf` - Output value definitions
- `README.md` - This documentation file

## Related Modules

- `eventbridge` - Creates EventBridge event buses
- `sqs` - Creates SQS queues
