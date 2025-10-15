data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_event_bus" "bus" {
  name = var.prefix != "" ? "${var.prefix}-${var.name}" : var.name

  dynamic "log_config" {
    for_each = var.log_retention_days > 0 ? [1] : []
    content {
      include_detail = var.log_include_detail
      level          = var.log_level
    }
  }

  tags = merge({
    Name = "eventbridge-${var.name}"
  }, var.tags)
}

resource "aws_schemas_registry" "registry" {
  count = length(var.schemas) > 0 || var.enable_schema_discovery ? 1 : 0

  name        = var.prefix != "" ? "${var.prefix}-${var.name}-registry" : "${var.name}-registry"
  description = "Schema registry for ${var.name} event bus"

  tags = merge({
    Name     = "eventbridge-registry-${var.name}"
    EventBus = aws_cloudwatch_event_bus.bus.name
  }, var.tags)
}

resource "aws_schemas_schema" "schema" {
  for_each = var.schemas

  name          = each.key
  registry_name = aws_schemas_registry.registry[0].name
  type          = each.value.type
  description   = each.value.description
  content       = each.value.content

  tags = merge({
    Name     = "schema-${each.key}"
    EventBus = aws_cloudwatch_event_bus.bus.name
  }, var.tags)

  depends_on = [aws_schemas_registry.registry]
}

resource "aws_schemas_discoverer" "discoverer" {
  count = var.enable_schema_discovery ? 1 : 0

  source_arn  = aws_cloudwatch_event_bus.bus.arn
  description = "Schema discoverer for ${var.name} event bus"

  tags = merge({
    Name     = "schema-discoverer-${var.name}"
    EventBus = aws_cloudwatch_event_bus.bus.name
  }, var.tags)
}

# CloudWatch Log Delivery Sources for EventBridge native logging
# AWS recommends creating all three log delivery sources and using the same destination
# The log level setting on the event bus controls which events are actually logged
resource "aws_cloudwatch_log_delivery_source" "error_logs" {
  count = var.log_retention_days > 0 ? 1 : 0

  name         = "EventBusSource-${aws_cloudwatch_event_bus.bus.name}-ERROR_LOGS"
  log_type     = "ERROR_LOGS"
  resource_arn = aws_cloudwatch_event_bus.bus.arn
}

resource "aws_cloudwatch_log_delivery_source" "info_logs" {
  count = var.log_retention_days > 0 ? 1 : 0

  name         = "EventBusSource-${aws_cloudwatch_event_bus.bus.name}-INFO_LOGS"
  log_type     = "INFO_LOGS"
  resource_arn = aws_cloudwatch_event_bus.bus.arn
}

resource "aws_cloudwatch_log_delivery_source" "trace_logs" {
  count = var.log_retention_days > 0 ? 1 : 0

  name         = "EventBusSource-${aws_cloudwatch_event_bus.bus.name}-TRACE_LOGS"
  log_type     = "TRACE_LOGS"
  resource_arn = aws_cloudwatch_event_bus.bus.arn
}

# CloudWatch Log Group for EventBridge logs - single destination for all log types
resource "aws_cloudwatch_log_group" "eventbridge" {
  count = var.log_retention_days > 0 ? 1 : 0

  name              = "/aws/vendedlogs/events/event-bus/${aws_cloudwatch_event_bus.bus.name}"
  retention_in_days = var.log_retention_days

  tags = merge({
    Name     = "eventbridge-logs-${var.name}"
    EventBus = aws_cloudwatch_event_bus.bus.name
  }, var.tags)
}

# IAM policy document allowing CloudWatch Log Delivery to write to CloudWatch Logs
data "aws_iam_policy_document" "eventbridge_to_logs" {
  count = var.log_retention_days > 0 ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.eventbridge[0].arn}:log-stream:*"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        aws_cloudwatch_log_delivery_source.error_logs[0].arn,
        aws_cloudwatch_log_delivery_source.info_logs[0].arn,
        aws_cloudwatch_log_delivery_source.trace_logs[0].arn
      ]
    }
  }
}

# CloudWatch Log Resource Policy to allow EventBridge to write logs
resource "aws_cloudwatch_log_resource_policy" "eventbridge_logs" {
  count = var.log_retention_days > 0 ? 1 : 0

  policy_name     = "AWSLogDeliveryWrite-${aws_cloudwatch_event_bus.bus.name}"
  policy_document = data.aws_iam_policy_document.eventbridge_to_logs[0].json
}

# CloudWatch Log Delivery Destination - single destination for all log types (AWS recommended)
resource "aws_cloudwatch_log_delivery_destination" "cwlogs" {
  count = var.log_retention_days > 0 ? 1 : 0

  name = "EventsDeliveryDestination-${aws_cloudwatch_event_bus.bus.name}-CWLogs"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.eventbridge[0].arn
  }
}

# CloudWatch Log Deliveries - all three log types go to the same destination
# AWS recommendation: "We recommend using the same log destination for all log level event delivery"
resource "aws_cloudwatch_log_delivery" "error_logs" {
  count = var.log_retention_days > 0 ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cwlogs[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.error_logs[0].name
}

resource "aws_cloudwatch_log_delivery" "info_logs" {
  count = var.log_retention_days > 0 ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cwlogs[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.info_logs[0].name

  depends_on = [aws_cloudwatch_log_delivery.error_logs]
}

resource "aws_cloudwatch_log_delivery" "trace_logs" {
  count = var.log_retention_days > 0 ? 1 : 0

  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.cwlogs[0].arn
  delivery_source_name     = aws_cloudwatch_log_delivery_source.trace_logs[0].name

  depends_on = [aws_cloudwatch_log_delivery.info_logs]
}

# EventBridge archive for event replay
resource "aws_cloudwatch_event_archive" "archive" {
  count = var.archive_retention_days > 0 ? 1 : 0

  name             = var.prefix != "" ? "${var.prefix}-${var.name}-archive" : "${var.name}-archive"
  event_source_arn = aws_cloudwatch_event_bus.bus.arn
  retention_days   = var.archive_retention_days
  description      = "Archive of all events for ${var.name} event bus"

  depends_on = [aws_cloudwatch_event_bus.bus]
}


