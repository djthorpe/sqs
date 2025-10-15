resource "aws_s3_bucket" "bucket" {
  for_each = toset(var.buckets)

  bucket        = var.prefix != "" ? "${var.prefix}-${each.value}" : each.value
  force_destroy = true

  tags = merge({
    Name = "s3-${each.value}"
  }, var.tags)
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle" {
  for_each = var.expiration_days != null || length(var.transitions) > 0 ? toset(var.buckets) : []

  bucket = aws_s3_bucket.bucket[each.value].id

  rule {
    id     = "lifecycle-rule"
    status = "Enabled"

    dynamic "transition" {
      for_each = var.transitions
      content {
        days          = transition.value.days
        storage_class = transition.value.storage_class
      }
    }

    dynamic "expiration" {
      for_each = var.expiration_days != null ? [1] : []
      content {
        days = var.expiration_days
      }
    }
  }
}
