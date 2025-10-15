# Root Workspace

This Terraform workspace creates a complete event-driven architecture with SQS queues and EventBridge.

## Architecture

```
┌──────────────┐
│ Source Queue │
└──────┬───────┘
       │
       ▼
┌──────────────────┐       ┌─────────────────┐
│ EventBridge Pipe │──────▶│ EventBridge Bus │
└──────────────────┘       └────────┬────────┘
                                    │
                                    ▼
                           ┌────────────────┐
                           │ EventBridge    │
                           │ Rule           │
                           └────────┬───────┘
                                    │
                                    ▼
                           ┌────────────────┐
                           │ Target Queue   │
                           └────────────────┘
```

## Resources Created

### SQS Queues

- **source** - Source queue that feeds events to EventBridge
- **target** - Target queue that receives events from EventBridge

Both queues include:

- Dead letter queues
- 4-day message retention
- 1-hour visibility timeout
- Long polling enabled (20 seconds)

### EventBridge

- **Event Bus** - Custom event bus for the service
- **Event Schemas** - Automatically registered from `etc/eventschema/*.json`
- **Pipe** - Connects source queue to EventBridge
- **Rule** - Routes events from EventBridge to target queue

## Event Schemas

Event schemas are automatically loaded from `etc/eventschema/` directory. Currently includes:

- **OrderCreated** - New order creation events
- **OrderUpdated** - Order status update events  
- **PaymentProcessed** - Payment processing events

To add new schemas, simply add `.json` files to the `etc/eventschema/` directory using JSON Schema Draft 4 format.

## Event Flow

1. **Messages arrive** in the source queue
2. **EventBridge Pipe** reads messages (batch of 10, 5-second window)
3. **Events published** to EventBridge bus with schemas
4. **EventBridge Rule** matches events from the service source
5. **Events delivered** to target queue

## Usage

### Initialize and Plan

```bash
cd tf/workspaces/root
terraform init
terraform plan -var="env=dev" -var="team=myteam" -var="service=orders"
```

### Apply

```bash
terraform apply -var="env=dev" -var="team=myteam" -var="service=orders"
```

### Using Terraform Variables File

Create `terraform.tfvars`:

```hcl
env     = "dev"
team    = "platform"
service = "orders"
```

Then:

```bash
terraform apply
```

### Destroy

```bash
terraform destroy -var="env=dev" -var="team=myteam" -var="service=orders"
```

## Variables

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `env` | Environment (prd, stg, dev) | Yes | - |
| `team` | Team name | Yes | - |
| `service` | Service name | Yes | - |
| `aws_region` | AWS region | No | `eu-central-1` |

## Outputs

| Name | Description |
|------|-------------|
| `source_queue_url` | URL of the source queue |
| `source_queue_arn` | ARN of the source queue |
| `target_queue_url` | URL of the target queue |
| `target_queue_arn` | ARN of the target queue |
| `event_bus_name` | Name of the EventBridge bus |
| `event_bus_arn` | ARN of the EventBridge bus |
| `pipe_name` | Name of the pipe connecting SQS to EventBridge |
| `rule_name` | Name of the rule routing events to target queue |
| `registered_schemas` | List of registered event schemas |

## Testing

### Send a Message to Source Queue

```bash
# Get queue URL from outputs
QUEUE_URL=$(terraform output -raw source_queue_url)

# Send a test message
aws sqs send-message \
  --queue-url "$QUEUE_URL" \
  --message-body '{
    "orderId": "ORD-12345",
    "customerId": "CUST-67890",
    "amount": 99.99,
    "currency": "USD",
    "status": "pending",
    "timestamp": "2025-10-15T12:00:00Z"
  }'
```

### Receive Messages from Target Queue

```bash
# Get target queue URL
TARGET_URL=$(terraform output -raw target_queue_url)

# Receive messages
aws sqs receive-message \
  --queue-url "$TARGET_URL" \
  --max-number-of-messages 10 \
  --wait-time-seconds 20
```

### View EventBridge Events

```bash
# Get event bus name
BUS_NAME=$(terraform output -raw event_bus_name)

# View event archive (if enabled)
aws events describe-archive --archive-name my-archive

# List rules on the bus
aws events list-rules --event-bus-name "$BUS_NAME"
```

### View Registered Schemas

```bash
# List registered schemas
terraform output registered_schemas

# View schema registry
REGISTRY_NAME=$(terraform output -raw event_bus_name)-registry
aws schemas list-schemas --registry-name "$REGISTRY_NAME"

# Get specific schema
aws schemas describe-schema \
  --registry-name "$REGISTRY_NAME" \
  --schema-name "OrderCreated"
```

## Adding New Event Schemas

1. Create a new JSON Schema file in `etc/eventschema/`:

```bash
cat > ../../../etc/eventschema/CustomerCreated.json << 'EOF'
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "type": "object",
  "properties": {
    "customerId": { "type": "string" },
    "email": { "type": "string", "format": "email" },
    "name": { "type": "string" },
    "timestamp": { "type": "string", "format": "date-time" }
  },
  "required": ["customerId", "email", "timestamp"]
}
EOF
```

2. Apply the changes:

```bash
terraform apply
```

The schema will be automatically registered with EventBridge.

## Resource Naming

All resources are prefixed with `{team}-{env}` or just `{env}` if team is not specified:

- Queues: `{prefix}-source`, `{prefix}-target`
- Event Bus: `{prefix}-events`
- Pipe: `{prefix}-source-to-events`
- Rule: `{prefix}-events-to-target`

Example with `team=platform` and `env=dev`:

- Queue: `platform-dev-source`
- Event Bus: `platform-dev-events`

## Notes

- Messages in the source queue are automatically deleted after successful processing
- Failed messages go to dead letter queues after max receive count
- Event schemas provide validation and documentation
- The pipe processes messages in batches for efficiency
- FIFO queues can be used by modifying the SQS module configuration
- Cross-region event routing can be configured by adding additional rules

## Related Modules

- `../../module/aws/sqs` - SQS queue management
- `../../module/aws/eventbridge` - EventBridge bus and schemas
- `../../module/aws/eventbridge_sqs_source` - SQS to EventBridge pipe
- `../../module/aws/eventbridge_sqs_target` - EventBridge to SQS rule
