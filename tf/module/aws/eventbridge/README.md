# AWS EventBridge Module

This Terraform module creates a single EventBridge event bus with optional schema registry for event-driven architectures.

## Features

- Creates a custom event bus
- Optional schema registry with JSON schema validation
- Schema discovery for automatic event schema detection
- Support for OpenAPI 3.0 and JSON Schema Draft 4 formats
- Optional CloudWatch Logs integration for event logging and monitoring
- Automatic log retention and deletion based on configurable hours
- Event archive for replaying past events
- Optional prefix for resource naming
- Custom tagging support

## Note

This module creates an event bus and optionally manages schemas. For rules and targets, use the companion modules:

- `eventbridge_sqs_target` - For routing events to SQS queues
- Other target modules as needed

## Usage

### Basic Example

```hcl
module "orders_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "orders"
  prefix = "myapp"
  
  tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

### Without Prefix

```hcl
module "payments_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name = "payments"
  
  tags = {
    Environment = "production"
  }
}
```

### Complete Example with SQS Targets

```hcl
# Create event bus
module "orders_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "orders"
  prefix = "myapp"
}

# Create SQS queue
module "sqs" {
  source = "./tf/module/aws/sqs"
  
  queues = ["order-processor"]
  prefix = "myapp"
}

# Route events to SQS
module "order_events_to_sqs" {
  source = "./tf/module/aws/eventbridge_sqs_target"
  
  eventbus = module.orders_eventbridge.name
  queue    = module.sqs.names["order-processor"]
  
  rule_name = "order-created"
  prefix    = "myapp"
  
  event_pattern = jsonencode({
    source      = ["myapp.orders"]
    detail-type = ["Order Created"]
  })
}
```

### Multiple Event Buses

```hcl
# Orders event bus
module "orders_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "orders"
  prefix = "myapp"
}

# Payments event bus
module "payments_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "payments"
  prefix = "myapp"
}

# Notifications event bus
module "notifications_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "notifications"
  prefix = "myapp"
}
```

### With Schema Registry and JSON Schema

```hcl
module "orders_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "orders"
  prefix = "myapp"
  
  # Schema registry is automatically created when schemas are defined
  schemas = {
    "OrderCreated" = {
      type        = "JSONSchemaDraft4"
      description = "Schema for order creation events"
      content = jsonencode({
        "$schema" = "http://json-schema.org/draft-04/schema#"
        type      = "object"
        properties = {
          orderId = {
            type        = "string"
            description = "Unique order identifier"
          }
          customerId = {
            type        = "string"
            description = "Customer identifier"
          }
          amount = {
            type        = "number"
            description = "Order amount"
            minimum     = 0
          }
          currency = {
            type    = "string"
            pattern = "^[A-Z]{3}$"
          }
          items = {
            type = "array"
            items = {
              type = "object"
              properties = {
                sku      = { type = "string" }
                quantity = { type = "integer", minimum = 1 }
                price    = { type = "number", minimum = 0 }
              }
              required = ["sku", "quantity", "price"]
            }
          }
          timestamp = {
            type   = "string"
            format = "date-time"
          }
        }
        required = ["orderId", "customerId", "amount", "currency", "timestamp"]
      })
    }
    "OrderUpdated" = {
      type        = "JSONSchemaDraft4"
      description = "Schema for order update events"
      content = jsonencode({
        "$schema" = "http://json-schema.org/draft-04/schema#"
        type      = "object"
        properties = {
          orderId = {
            type = "string"
          }
          status = {
            type = "string"
            enum = ["pending", "processing", "shipped", "delivered", "cancelled"]
          }
          timestamp = {
            type   = "string"
            format = "date-time"
          }
        }
        required = ["orderId", "status", "timestamp"]
      })
    }
  }
  
  tags = {
    Environment = "production"
  }
}
```

### With Automatic Schema Discovery

```hcl
module "orders_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name                     = "orders"
  prefix                   = "myapp"
  enable_schema_discovery  = true  # Registry created automatically
  
  tags = {
    Environment = "production"
  }
}

# Schema discoverer will automatically detect and create schemas
# from events published to this bus
```

### With OpenAPI 3.0 Schema

```hcl
module "api_events_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "api-events"
  prefix = "myapp"
  
  schemas = {
    "ApiRequestEvent" = {
      type        = "OpenApi3"
      description = "Schema for API request events"
      content = jsonencode({
        openapi = "3.0.0"
        info = {
          version = "1.0.0"
          title   = "API Request Event"
        }
        paths = {}
        components = {
          schemas = {
            AWSEvent = {
              type = "object"
              properties = {
                detail = {
                  "$ref" = "#/components/schemas/ApiRequest"
                }
              }
            }
            ApiRequest = {
              type = "object"
              properties = {
                requestId = { type = "string" }
                method    = { type = "string", enum = ["GET", "POST", "PUT", "DELETE"] }
                path      = { type = "string" }
                statusCode = { type = "integer" }
                duration   = { type = "number" }
              }
              required = ["requestId", "method", "path", "statusCode"]
            }
          }
        }
      })
    }
  }
}
```

### With CloudWatch Logs Logging (Basic)

```hcl
module "orders_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "orders"
  prefix = "myapp"
  
  # Enable logging with default INFO level
  log_retention_days = 3  # Keep logs for 3 days
  
  tags = {
    Environment = "production"
  }
}

# Access log group name and ARN from outputs
output "orders_log_group" {
  value = module.orders_eventbridge.log_group_name
}

# Output example:
# "/aws/vendedlogs/events/event-bus/myapp-orders"
```

### With CloudWatch Logs Logging (Advanced)

```hcl
module "orders_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "orders"
  prefix = "myapp"
  
  # Enable detailed logging with TRACE level
  log_retention_days  = 7       # Keep logs for 7 days
  log_level           = "TRACE" # Log everything including internal EventBridge activity
  log_include_detail  = "FULL"  # Include full event payloads
  
  tags = {
    Environment = "development"
  }
}
```

### With Event Archive for Replay

```hcl
module "orders_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "orders"
  prefix = "myapp"
  
  # Enable event archive for disaster recovery
  archive_retention_days = 7  # Keep archive for 7 days
  
  tags = {
    Environment = "production"
  }
}

# Access archive name from outputs
output "orders_archive" {
  value = module.orders_eventbridge.archive_name
}
```

### Production Example with Logging, Archive, and Schemas

```hcl
module "orders_eventbridge" {
  source = "./tf/module/aws/eventbridge"
  
  name   = "orders"
  prefix = "myapp"
  
  # Enable comprehensive event logging
  log_retention_days     = 3   # 3 days for debugging
  archive_retention_days = 30  # 30 days for replay/recovery
  
  # Define event schemas
  schemas = {
    "OrderCreated" = {
      type        = "JSONSchemaDraft4"
      description = "Order creation event schema"
      content = jsonencode({
        "$schema" = "http://json-schema.org/draft-04/schema#"
        type      = "object"
        properties = {
          orderId   = { type = "string" }
          timestamp = { type = "string", format = "date-time" }
        }
        required = ["orderId", "timestamp"]
      })
    }
  }
  
  tags = {
    Environment = "production"
    Team        = "orders"
  }
}
```

## Inputs

| Name | Type | Description | Default | Required |
|------|------|-------------|---------|----------|
| `name` | `string` | Name of the event bus to create | - | Yes |
| `prefix` | `string` | Prefix to add to the event bus name | `""` | No |
| `schemas` | `map(object)` | Map of schema definitions (see below) | `{}` | No |
| `enable_schema_discovery` | `bool` | Enable automatic schema discovery | `false` | No |
| `log_retention_days` | `number` | Days to retain CloudWatch logs (0 = disabled, >0 = enabled) | `0` | No |
| `log_level` | `string` | Log level for EventBridge (OFF, ERROR, INFO, TRACE) | `INFO` | No |
| `log_include_detail` | `string` | Include full event detail in logs (NONE, FULL) | `FULL` | No |
| `archive_retention_days` | `number` | Days to retain event archive (0 = disabled, >0 = enabled) | `0` | No |
| `tags` | `map(string)` | Additional tags to apply to all resources | `{}` | No |

**Note**: A schema registry is automatically created when either `schemas` contains one or more schemas, or `enable_schema_discovery` is `true`.

### Schema Object

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `type` | `string` | Schema type: `OpenApi3` or `JSONSchemaDraft4` | Yes |
| `description` | `string` | Description of the schema | No |
| `content` | `string` | JSON-encoded schema content | Yes |

## Outputs

| Name | Description |
|------|-------------|
| `name` | Name of the event bus |
| `arn` | ARN of the event bus |
| `log_group_name` | Name of the CloudWatch log group (null if logging disabled) |
| `log_group_arn` | ARN of the CloudWatch log group (null if logging disabled) |
| `archive_name` | Name of the event archive (null if archive not enabled) |

## Example Output Usage

```hcl
output "orders_bus_arn" {
  value = module.orders_eventbridge.arn
}

output "orders_bus_name" {
  value = module.orders_eventbridge.name
}
```

## Schema Registry Benefits

- **Event Validation** - Validate events against schemas before processing
- **Documentation** - Auto-generated documentation for event structures
- **Code Generation** - Generate code bindings in various languages
- **Versioning** - Track schema changes over time
- **Discovery** - Automatically infer schemas from events (when enabled)

## Schema Discovery

When `enable_schema_discovery` is set to `true`, EventBridge will:

- Monitor events published to the bus
- Automatically infer the structure of events
- Create and update schemas in the registry
- Version schemas as event structures evolve

This is useful for development and testing, but for production, explicitly defined schemas are recommended.

## CloudWatch Logs Integration

When `log_retention_days` is greater than 0, this module uses **EventBridge native logging** (not event rules):

### What Gets Created

1. **EventBridge Log Configuration** - Configured directly on the event bus
   - Uses `log_config` block with `level` and `include_detail` settings
   - Native EventBridge feature (no event rules needed)
   - The `level` setting controls which events are actually logged

2. **CloudWatch Log Delivery Sources** - All three are always created when logging is enabled
   - `ERROR_LOGS` - Error events (always included when logging enabled)
   - `INFO_LOGS` - Informational events (included when level is INFO or TRACE)
   - `TRACE_LOGS` - Detailed trace events (included when level is TRACE)
   - AWS recommends using the same destination for all three log types

3. **CloudWatch Log Group** - Single log group for all log types (AWS recommended)
   - Log group name: `/aws/vendedlogs/events/event-bus/{bus-name}`
   - All log types (ERROR, INFO, TRACE) write to the same group
   - Retention based on `log_retention_days`
   - Automatic deletion after retention period expires

4. **CloudWatch Log Delivery Destination** - Single destination for all log types
   - Routes all log types to the same log group
   - Managed by AWS CloudWatch Log Delivery service
   - Follows AWS recommendation: "We recommend using the same log destination for all log level event delivery"

5. **CloudWatch Log Deliveries** - Connects sources to destination
   - Three deliveries (ERROR, INFO, TRACE) all pointing to the same destination
   - Depends on each other to avoid conflicts

6. **CloudWatch Log Resource Policy** - Grants permissions
   - Allows `delivery.logs.amazonaws.com` to write logs
   - Scoped to specific account and source ARNs
   - Uses AWS recommended security conditions

## Event Archive

When `archive_retention_days` is greater than 0, this module creates:

- **Event Archive** - Stores events for replay capability
  - Archive name: `{prefix}-{name}-archive` or `{name}-archive`
  - Retention based on `archive_retention_days`
  - Enables event replay for disaster recovery or debugging
  - Independent from CloudWatch Logs - can be enabled separately

### Log Levels

The `log_level` variable controls what gets logged:

- **`OFF`** - No logging (same as `log_retention_days = 0`)
- **`ERROR`** - Only errors (failed event deliveries, rule evaluation errors)
- **`INFO`** - Errors + informational messages (successful deliveries, rule matches)
- **`TRACE`** - Everything including internal EventBridge operations (most verbose)

### Log Detail

The `log_include_detail` variable controls event payload logging:

- **`NONE`** - Log metadata only (no event payloads)
- **`FULL`** - Log complete event payloads (default, useful for debugging)

### Log Retention

The `log_retention_days` variable specifies how long to keep logs. After the retention period, logs are automatically deleted to control costs.

Common values:

- `1` - 1 day (short-term debugging)
- `3` - 3 days (typical debugging)
- `7` - 7 days (weekly review)
- `14` - 14 days (bi-weekly)
- `30` - 30 days (monthly compliance)
- `90` - 90 days (quarterly)
- `365` - 1 year (annual compliance)

### Recommendations

**Development:**

```hcl
log_retention_days  = 3
log_level           = "TRACE"
log_include_detail  = "FULL"
```

**Production:**

```hcl
log_retention_days  = 7
log_level           = "INFO"    # or "ERROR" to reduce volume
log_include_detail  = "FULL"    # or "NONE" for compliance
```

### Use Cases for Logging

- **Debugging** - Inspect event payloads and flow
- **Audit Trail** - Compliance and security monitoring
- **Troubleshooting** - Identify integration issues
- **Replay** - Use archives to replay events after fixing issues
- **Metrics** - Analyze event patterns and volumes

### Log Format

Events are logged in JSON format with full AWS event structure:

```json
{
  "version": "0",
  "id": "event-id",
  "detail-type": "Order Created",
  "source": "myapp.orders",
  "account": "123456789012",
  "time": "2024-01-15T12:00:00Z",
  "region": "us-east-1",
  "resources": [],
  "detail": {
    "orderId": "order-123",
    "customerId": "cust-456",
    "amount": 99.99
  }
}
```

## JSON Schema Draft 4 Example

```json
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "type": "object",
  "properties": {
    "eventId": { "type": "string" },
    "eventType": { "type": "string", "enum": ["created", "updated"] },
    "data": {
      "type": "object",
      "properties": {
        "id": { "type": "string" },
        "name": { "type": "string" }
      },
      "required": ["id"]
    }
  },
  "required": ["eventId", "eventType"]
}
```

## OpenAPI 3.0 Schema Example

```json
{
  "openapi": "3.0.0",
  "info": {
    "version": "1.0.0",
    "title": "Event Schema"
  },
  "paths": {},
  "components": {
    "schemas": {
      "AWSEvent": {
        "type": "object",
        "properties": {
          "detail": {
            "$ref": "#/components/schemas/EventDetail"
          }
        }
      }
    }
  }
}
```

## Notes

- Event bus names are unique within an AWS account in a region
- The default event bus (`default`) is always available and doesn't need to be created
- To create multiple event buses, instantiate this module multiple times with different names
- Schema registries are automatically created when schemas are defined or discovery is enabled
- Schema discovery is useful for development but explicit schemas are better for production
- Schemas support versioning - updates create new versions automatically
- Use companion modules like `eventbridge_sqs_target` to create rules and targets
- This module manages a single event bus with its associated schemas

## Requirements

- Terraform >= 1.0
- AWS Provider

## Module Files

- `main.tf` - Event bus resource definitions
- `input.tf` - Input variable declarations
- `outputs.tf` - Output value definitions
- `README.md` - This documentation file

## Related Modules

- `eventbridge_sqs_target` - Routes events to SQS queues
