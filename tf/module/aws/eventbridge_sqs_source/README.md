# AWS EventBridge SQS Source Module

This Terraform module creates an EventBridge Pipe that reads messages from an SQS queue and publishes them as events to an EventBridge event bus.

## Features

- Creates EventBridge Pipe to connect SQS to EventBridge
- Automatically configures IAM roles and policies
- Supports message batching and windowing
- Optional message filtering
- Optional message transformation
- Handles both standard and FIFO SQS queues
- Custom tagging support

## Use Cases

- Convert queue-based messages to event-driven architecture
- Bridge legacy SQS-based systems to EventBridge
- Enable fan-out patterns from SQS messages
- Transform queue messages into standardized events
- Filter and route specific SQS messages to EventBridge

## Usage

### Basic Example

```hcl
module "sqs_to_eventbridge" {
  source = "./tf/module/aws/eventbridge_sqs_source"
  
  name           = "order-events"
  prefix         = "myapp"
  
  sqs_queue_arn  = "arn:aws:sqs:us-east-1:123456789012:orders"
  event_bus_arn  = "arn:aws:events:us-east-1:123456789012:event-bus/orders"
  
  detail_type    = "Order Message"
  event_source   = "myapp.orders.sqs"
}
```

### With Module References

```hcl
# Create SQS queue
module "sqs" {
  source = "./tf/module/aws/sqs"
  
  queues = ["orders"]
  prefix = "myapp"
}

# Create EventBridge bus
module "eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "orders"
  prefix = "myapp"
}

# Connect SQS to EventBridge
module "sqs_to_eventbridge" {
  source = "./tf/module/aws/eventbridge_sqs_source"
  
  name           = "order-events"
  prefix         = "myapp"
  
  sqs_queue_arn  = module.sqs.queue_arns["orders"]
  event_bus_arn  = module.eventbridge.arn
  
  detail_type    = "Order Message"
  event_source   = "myapp.orders"
}
```

### With Batching

```hcl
module "sqs_to_eventbridge" {
  source = "./tf/module/aws/eventbridge_sqs_source"
  
  name           = "payment-events"
  prefix         = "myapp"
  
  sqs_queue_arn  = module.sqs.queue_arns["payments"]
  event_bus_arn  = module.eventbridge.arn
  
  detail_type    = "Payment Message"
  event_source   = "myapp.payments"
  
  batch_size                        = 100
  maximum_batching_window_seconds   = 10
}
```

### With Message Filtering

```hcl
module "sqs_to_eventbridge" {
  source = "./tf/module/aws/eventbridge_sqs_source"
  
  name           = "high-priority-orders"
  prefix         = "myapp"
  
  sqs_queue_arn  = module.sqs.queue_arns["orders"]
  event_bus_arn  = module.eventbridge.arn
  
  detail_type    = "Order Message"
  event_source   = "myapp.orders.high-priority"
  
  # Only process messages with priority = high
  filter_pattern = jsonencode({
    body = {
      priority = ["high"]
    }
  })
}
```

### With Input Transformation

```hcl
module "sqs_to_eventbridge" {
  source = "./tf/module/aws/eventbridge_sqs_source"
  
  name           = "order-events"
  prefix         = "myapp"
  
  sqs_queue_arn  = module.sqs.queue_arns["orders"]
  event_bus_arn  = module.eventbridge.arn
  
  detail_type    = "Order Processed"
  event_source   = "myapp.orders"
  
  # Transform SQS message to EventBridge event format
  input_template = jsonencode({
    orderId     = "<$.body.orderId>"
    customerId  = "<$.body.customerId>"
    amount      = "<$.body.amount>"
    processedAt = "<aws.pipes.event.ingestion-time>"
  })
}
```

### Complete Multi-Stage Pipeline

```hcl
# Stage 1: SQS queues
module "sqs" {
  source = "./tf/module/aws/sqs"
  
  queues = ["raw-orders", "processed-orders"]
  prefix = "myapp"
  
  visibility_timeout_hours = 1
  message_retention_hours  = 48
}

# Stage 2: EventBridge bus
module "eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "orders"
  prefix = "myapp"
  
  schemas = {
    "OrderProcessed" = {
      type = "JSONSchemaDraft4"
      content = jsonencode({
        "$schema" = "http://json-schema.org/draft-04/schema#"
        type      = "object"
        properties = {
          orderId    = { type = "string" }
          customerId = { type = "string" }
          amount     = { type = "number" }
        }
        required = ["orderId"]
      })
    }
  }
}

# Stage 3: SQS to EventBridge pipe
module "sqs_to_eventbridge" {
  source = "./tf/module/aws/eventbridge_sqs_source"
  
  name           = "order-processor"
  prefix         = "myapp"
  
  sqs_queue_arn  = module.sqs.queue_arns["raw-orders"]
  event_bus_arn  = module.eventbridge.arn
  
  detail_type    = "Order Processed"
  event_source   = "myapp.orders"
  
  batch_size                       = 50
  maximum_batching_window_seconds  = 5
}

# Stage 4: EventBridge to processed queue
module "eventbridge_to_sqs" {
  source = "./tf/module/aws/eventbridge_sqs_target"
  
  rule_name      = "processed-orders"
  prefix         = "myapp"
  event_bus_name = module.eventbridge.name
  
  event_pattern = jsonencode({
    source      = ["myapp.orders"]
    detail-type = ["Order Processed"]
  })
  
  sqs_queue_arn  = module.sqs.queue_arns["processed-orders"]
  sqs_queue_name = module.sqs.queue_names["processed-orders"]
}
```

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `name` | `string` | Name of the pipe | - | Yes |
| `prefix` | `string` | Prefix to add to resource names | `""` | No |
| `sqs_queue_arn` | `string` | ARN of the source SQS queue | - | Yes |
| `event_bus_arn` | `string` | ARN of the target EventBridge event bus | - | Yes |
| `detail_type` | `string` | The detail-type for events sent to EventBridge | - | Yes |
| `event_source` | `string` | The source identifier for events sent to EventBridge | - | Yes |
| `batch_size` | `number` | Maximum messages per batch (1-10000) | `10` | No |
| `maximum_batching_window_seconds` | `number` | Max batching window in seconds (0-300) | `0` | No |
| `filter_pattern` | `string` | Event filter pattern in JSON format | `null` | No |
| `input_template` | `string` | Input template for message transformation | `null` | No |
| `tags` | `map(string)` | Additional tags to apply to resources | `{}` | No |

## Outputs

| Name | Description |
|------|-------------|
| `pipe_name` | Name of the EventBridge pipe |
| `pipe_arn` | ARN of the EventBridge pipe |
| `pipe_id` | ID of the EventBridge pipe |
| `role_arn` | ARN of the IAM role used by the pipe |

## Filter Pattern Examples

### Filter by Message Attribute

```json
{
  "body": {
    "status": ["completed"]
  }
}
```

### Filter by Multiple Conditions

```json
{
  "body": {
    "priority": ["high", "critical"],
    "amount": [{"numeric": [">", 1000]}]
  }
}
```

### Filter by Nested Properties

```json
{
  "body": {
    "order": {
      "status": ["confirmed"],
      "customer": {
        "type": ["premium"]
      }
    }
  }
}
```

## Input Transformation Examples

### Basic Field Mapping

```json
{
  "orderId": "<$.body.id>",
  "timestamp": "<aws.pipes.event.ingestion-time>"
}
```

### Complex Transformation

```json
{
  "eventId": "<$.messageId>",
  "eventType": "ORDER_RECEIVED",
  "data": {
    "orderId": "<$.body.orderId>",
    "customer": "<$.body.customerId>",
    "total": "<$.body.amount>"
  },
  "metadata": {
    "source": "sqs",
    "ingestionTime": "<aws.pipes.event.ingestion-time>"
  }
}
```

## Event Structure

Messages from SQS are sent to EventBridge with this structure:

```json
{
  "version": "0",
  "id": "event-id",
  "detail-type": "Order Message",
  "source": "myapp.orders",
  "account": "123456789012",
  "time": "2025-10-15T12:00:00Z",
  "region": "us-east-1",
  "resources": [],
  "detail": {
    // SQS message body (or transformed content)
  }
}
```

## IAM Permissions

This module automatically creates:

1. **IAM Role** for EventBridge Pipes with trust policy for `pipes.amazonaws.com`
2. **SQS Source Policy** allowing:
   - `sqs:ReceiveMessage`
   - `sqs:DeleteMessage`
   - `sqs:GetQueueAttributes`
3. **EventBridge Target Policy** allowing:
   - `events:PutEvents`

No additional IAM configuration is required.

## Notes

- EventBridge Pipes automatically handle message deletion from SQS after successful processing
- Failed messages are not deleted and will be retried based on SQS settings
- Use SQS dead letter queues to handle messages that fail repeatedly
- Batch size and batching window can optimize throughput and cost
- Filter patterns reduce unnecessary event processing
- Input transformation happens before events reach EventBridge
- The pipe runs continuously and scales automatically
- Standard and FIFO SQS queues are both supported
- Messages are processed in order for FIFO queues
- Consider using message deduplication for FIFO queues

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0 (for EventBridge Pipes support)

## Module Files

- `main.tf` - Pipe and IAM resources
- `input.tf` - Input variable declarations
- `outputs.tf` - Output value definitions
- `README.md` - This documentation file

## Related Modules

- `eventbridge` - Creates EventBridge event buses
- `eventbridge_sqs_target` - Routes events from EventBridge to SQS
- `sqs` - Creates SQS queues
