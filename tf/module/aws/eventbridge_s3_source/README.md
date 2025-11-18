# EventBridge S3 Source Module

This module creates an integration between an S3 bucket and EventBridge, automatically forwarding S3 events from the default EventBridge bus to a custom EventBridge event bus.

## Features

- Configures S3 bucket notifications to send events to the default EventBridge bus
- Creates EventBridge rules on the default bus to capture and filter S3 events
- Forwards filtered S3 events to a custom EventBridge bus
- Supports filtering by object key prefix and/or suffix
- Forwards S3 events to EventBridge in their original format
- Configurable event types (create, delete, etc.)

## Usage

```hcl
module "s3_to_eventbridge" {
  source = "./module/aws/eventbridge_s3_source"

  name   = "my-s3-events"
  prefix = "myproject"
  bucket = "my-source-bucket"
  eventbus = aws_cloudwatch_event_bus.main.name

  event_types = [
    "Object Created",
    "Object Deleted"
  ]

  filter_prefix = "uploads/"
  filter_suffix = ".json"

  tags = {
    Environment = "production"
    Project     = "myproject"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name of the S3 to EventBridge integration | `string` | n/a | yes |
| bucket | Name of the S3 bucket to monitor for events | `string` | n/a | yes |
| eventbus | Name of the EventBridge event bus (use 'default' for the default bus) | `string` | n/a | yes |
| prefix | Prefix to add to resource names | `string` | `""` | no |
| event_types | List of S3 event detail-types to monitor (e.g., `"Object Created"`, `"Object Deleted"`) | `list(string)` | `["Object Created", "Object Deleted"]` | no |
| filter_prefix | Object key prefix to filter events | `string` | `null` | no |
| filter_suffix | Object key suffix to filter events | `string` | `null` | no |
| tags | Additional tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| rule_name | Name of the EventBridge rule |
| rule_arn | ARN of the EventBridge rule |
| rule_id | ID of the EventBridge rule |
| target_id | ID of the event target |

## Event Structure

Events are forwarded to EventBridge in their original S3 format. A typical S3 event will have the following structure:

```json
{
  "version": "0",
  "id": "example-id",
  "detail-type": "Object Created",
  "source": "aws.s3",
  "account": "123456789012",
  "time": "2025-11-18T10:30:00Z",
  "region": "us-east-1",
  "detail": {
    "version": "0",
    "bucket": {
      "name": "my-source-bucket"
    },
    "object": {
      "key": "uploads/file.json",
      "size": 1024,
      "eTag": "d41d8cd98f00b204e9800998ecf8427e",
      "sequencer": "0A1B2C3D4E5F678901"
    },
    "request-id": "D82B88E5F771EC06",
    "requester": "123456789012"
  }
}
```

## Common S3 Event Detail-Types

- `Object Created` – umbrella detail-type for create events (specific operation appears in `detail.eventName`, e.g., `ObjectCreated:Put`)
- `Object Deleted` – emitted when objects are deleted (`detail.eventName` holds `ObjectRemoved:*` values)
- `Object Restore Initiated`
- `Object Restore Completed`
- `Object Restore Failed`
- `Lifecycle Expiration` / `Lifecycle Transition` (when lifecycle policies run)

> **Tip:** EventBridge matches on `detail-type`, while the more granular S3 action (`s3:ObjectCreated:Put`, etc.) is still available inside `detail.eventName`. Keep your rule pattern broad (e.g., `"Object Created"`) and add extra filters using `detail.eventName` or object key criteria if needed.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 4.0 |

## Resources

| Name | Type |
|------|------|
| aws_s3_bucket_notification.eventbridge | resource |
| aws_cloudwatch_event_rule.s3_events | resource |
| aws_cloudwatch_event_target.eventbridge_target | resource |
| aws_iam_role.eventbridge_role | resource |
| aws_iam_role_policy.eventbridge_policy | resource |

## Notes

- The S3 bucket must already exist before using this module
- EventBridge notifications are automatically enabled on the S3 bucket
- S3 events are first sent to the **default EventBridge bus**, then forwarded to your custom bus
- Events are passed through to the target event bus in their original S3 format
- The module provisions an IAM role that EventBridge assumes when forwarding to the custom bus
- The module creates a rule on the default bus and targets your custom bus
- IAM permissions are automatically configured for EventBridge to receive and forward events
