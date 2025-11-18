# Data source to get event bus ARN from name
data "aws_cloudwatch_event_bus" "target" {
  name = var.eventbus
}

# S3 bucket notification configuration to send events to default EventBridge bus
resource "aws_s3_bucket_notification" "eventbridge" {
  bucket      = var.bucket
  eventbridge = true
}

# EventBridge rule to capture S3 events on default bus and forward to custom bus
resource "aws_cloudwatch_event_rule" "s3_events" {
  name           = var.prefix != "" ? "${var.prefix}-${var.name}" : var.name
  description    = "EventBridge rule for S3 bucket ${var.bucket} events"
  event_bus_name = "default"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = var.event_types
    detail = merge(
      {
        bucket = {
          name = [var.bucket]
        }
      },
      var.filter_prefix != null ? {
        object = {
          key = [{
            prefix = var.filter_prefix
          }]
        }
      } : {},
      var.filter_suffix != null ? {
        object = {
          key = [{
            suffix = var.filter_suffix
          }]
        }
      } : {}
    )
  })

  tags = merge({
    Name   = "rule-${var.name}"
    Source = "S3"
    Target = "EventBridge"
  }, var.tags)
}

# EventBridge target for the rule - forwards events to custom bus
resource "aws_cloudwatch_event_target" "eventbridge_target" {
  rule           = aws_cloudwatch_event_rule.s3_events.name
  target_id      = "EventBridgeTarget"
  arn            = data.aws_cloudwatch_event_bus.target.arn
  event_bus_name = "default"
  role_arn       = aws_iam_role.eventbridge_role.arn
}

# IAM role for EventBridge to receive events from S3
resource "aws_iam_role" "eventbridge_role" {
  name = var.prefix != "" ? "${var.prefix}-${var.name}-eventbridge-role" : "${var.name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge({
    Name = "eventbridge-role-${var.name}"
  }, var.tags)
}

# IAM policy for EventBridge to put events
resource "aws_iam_role_policy" "eventbridge_policy" {
  name = "eventbridge-policy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = data.aws_cloudwatch_event_bus.target.arn
      }
    ]
  })
}
