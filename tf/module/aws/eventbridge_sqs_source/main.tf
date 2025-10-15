resource "aws_pipes_pipe" "sqs_to_eventbridge" {
  name     = var.prefix != "" ? "${var.prefix}-${var.name}" : var.name
  role_arn = aws_iam_role.pipe.arn

  source = var.sqs_queue_arn

  target = var.event_bus_arn

  source_parameters {
    sqs_queue_parameters {
      batch_size                         = var.batch_size
      maximum_batching_window_in_seconds = var.maximum_batching_window_seconds
    }

    dynamic "filter_criteria" {
      for_each = var.filter_pattern != null ? [1] : []
      content {
        filter {
          pattern = var.filter_pattern
        }
      }
    }
  }

  target_parameters {
    input_template = var.input_template

    eventbridge_event_bus_parameters {
      detail_type = var.detail_type
      source      = var.event_source
    }
  }

  tags = merge({
    Name   = "pipe-${var.name}"
    Source = "SQS"
    Target = "EventBridge"
  }, var.tags)
}

# IAM role for EventBridge Pipes
resource "aws_iam_role" "pipe" {
  name = var.prefix != "" ? "${var.prefix}-${var.name}-pipe-role" : "${var.name}-pipe-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pipes.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge({
    Name = "pipe-role-${var.name}"
  }, var.tags)
}

# IAM policy to read from SQS
resource "aws_iam_role_policy" "sqs_source" {
  name = "sqs-source"
  role = aws_iam_role.pipe.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = var.sqs_queue_arn
      }
    ]
  })
}

# IAM policy to write to EventBridge
resource "aws_iam_role_policy" "eventbridge_target" {
  name = "eventbridge-target"
  role = aws_iam_role.pipe.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = var.event_bus_arn
      }
    ]
  })
}
