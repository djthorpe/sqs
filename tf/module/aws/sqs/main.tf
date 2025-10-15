resource "aws_sqs_queue" "queue" {
  for_each = toset(var.queues)

  name = var.fifo_queue ? (
    var.prefix != "" ? "${var.prefix}-${each.value}.fifo" : "${each.value}.fifo"
    ) : (
    var.prefix != "" ? "${var.prefix}-${each.value}" : each.value
  )

  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null
  deduplication_scope         = var.fifo_queue ? var.deduplication_scope : null
  fifo_throughput_limit       = var.fifo_queue ? var.fifo_throughput_limit : null

  delay_seconds              = var.delay_hours * 3600
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.message_retention_hours * 3600
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_hours * 3600

  tags = merge({
    Name = "sqs-${each.value}"
  }, var.tags)
}

resource "aws_sqs_queue" "deadletter" {
  for_each = var.deadletter_message_retention_hours > 0 ? toset(var.queues) : []

  name = var.fifo_queue ? (
    var.prefix != "" ? "${var.prefix}-${each.value}-dlq.fifo" : "${each.value}-dlq.fifo"
    ) : (
    var.prefix != "" ? "${var.prefix}-${each.value}-dlq" : "${each.value}-dlq"
  )

  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null
  deduplication_scope         = var.fifo_queue ? var.deduplication_scope : null
  fifo_throughput_limit       = var.fifo_queue ? var.fifo_throughput_limit : null

  delay_seconds              = var.delay_hours * 3600
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.deadletter_message_retention_hours * 3600
  receive_wait_time_seconds  = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_hours * 3600

  tags = merge({
    Name = "sqs-${each.value}-dlq"
  }, var.tags)
}

resource "aws_sqs_queue_redrive_policy" "redrive" {
  for_each = var.deadletter_message_retention_hours > 0 ? toset(var.queues) : []

  queue_url = aws_sqs_queue.queue[each.value].id

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.deadletter[each.value].arn
    maxReceiveCount     = var.max_receive_count
  })
}
