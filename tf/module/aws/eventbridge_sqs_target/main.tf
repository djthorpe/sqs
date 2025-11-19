data "aws_sqs_queue" "target" {
  name = var.queue
}

resource "aws_cloudwatch_event_rule" "rule" {
  name                = var.prefix != "" ? "${var.prefix}-${var.rule_name}" : var.rule_name
  description         = var.rule_description
  event_bus_name      = var.eventbus
  event_pattern       = var.event_pattern
  schedule_expression = var.schedule_expression
  state               = var.enabled ? "ENABLED" : "DISABLED"

  tags = merge({
    Name = "eventbridge-rule-${var.rule_name}"
  }, var.tags)
}

resource "aws_cloudwatch_event_target" "sqs" {
  rule           = aws_cloudwatch_event_rule.rule.name
  event_bus_name = aws_cloudwatch_event_rule.rule.event_bus_name
  target_id      = var.target_id != "" ? var.target_id : "sqs-${var.rule_name}"
  arn            = data.aws_sqs_queue.target.arn
  role_arn       = var.role_arn

  dynamic "sqs_target" {
    for_each = var.sqs_message_group_id != null ? [1] : []
    content {
      message_group_id = var.sqs_message_group_id
    }
  }

  dynamic "input_transformer" {
    for_each = var.input_transformer != null ? [var.input_transformer] : []
    content {
      input_paths    = input_transformer.value.input_paths
      input_template = input_transformer.value.input_template
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_arn != null ? [1] : []
    content {
      arn = var.dead_letter_arn
    }
  }

  dynamic "retry_policy" {
    for_each = var.retry_policy != null ? [var.retry_policy] : []
    content {
      maximum_event_age_in_seconds = retry_policy.value.maximum_event_age_in_seconds
      maximum_retry_attempts       = retry_policy.value.maximum_retry_attempts
    }
  }
}

# IAM policy to allow EventBridge to send messages to SQS
resource "aws_sqs_queue_policy" "eventbridge" {
  count     = var.manage_queue_policy ? 1 : 0
  queue_url = data.aws_sqs_queue.target.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = data.aws_sqs_queue.target.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.rule.arn
          }
        }
      }
    ]
  })
}
