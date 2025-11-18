
locals {
  prefix = var.team != "" ? "${var.team}-${var.env}" : var.env

  # Read all JSON schema files from eventschema/custom directory
  schema_files = fileset("${path.root}/../../../eventschema/custom", "*.json")

  # Create schema map with schema name (filename without .json) => schema content
  schemas = {
    for file in local.schema_files :
    trimsuffix(file, ".json") => {
      type        = "JSONSchemaDraft4"
      description = "Event schema for ${trimsuffix(file, ".json")}"
      content     = file("${path.root}/../../../eventschema/custom/${file}")
    }
  }
}

# Create an S3 bucket for events
module "s3bucket" {
  source  = "../../module/aws/s3bucket"
  buckets = ["test2"]
  prefix  = local.prefix
}

# Create target SQS queue
module "sqs" {
  source                             = "../../module/aws/sqs"
  queues                             = ["target"]
  prefix                             = local.prefix
  visibility_timeout_hours           = 1
  message_retention_hours            = 96 # 4 days
  receive_wait_time_seconds          = 20
  deadletter_message_retention_hours = 24
}

# Create an EventBridge Bus and register schemas
module "eventbridge" {
  source  = "../../module/aws/eventbridge"
  name    = "events"
  prefix  = local.prefix
  schemas = local.schemas
}

# Route events back to target queue
module "eventbridge_to_sqs" {
  source    = "../../module/aws/eventbridge_sqs_target"
  rule_name = "events-to-target"
  prefix    = local.prefix
  eventbus  = module.eventbridge.name
  event_pattern = jsonencode({
    source = ["${var.service}.source"]
  })
  queue = module.sqs.names["target"]
}

# Create EventBridge rule to capture S3 events and send to EventBridge bus.
# what this actually does is to route appropriately from default bus messages
# to custom bus, since S3 events can only go to the default bus, in the same
# region as the S3 bucket.
module "s3_to_eventbridge" {
  for_each = module.s3bucket.names
  source   = "../../module/aws/eventbridge_s3_source"
  name     = "s3-to-eventbridge-${each.key}"
  prefix   = local.prefix
  bucket   = each.value
  eventbus = module.eventbridge.name
}

# Route S3 events (forwarded to custom bus) to the same target queue
module "eventbridge_s3_to_sqs" {
  for_each  = module.s3bucket.names
  source    = "../../module/aws/eventbridge_sqs_target"
  rule_name = "s3-events-to-${each.key}"
  prefix    = local.prefix
  eventbus  = module.eventbridge.name
  event_pattern = jsonencode({
    source = ["aws.s3"]
    detail-type = [
      "Object Created",
      "Object Deleted"
    ]
    detail = {
      bucket = {
        name = [each.value]
      }
    }
  })
  queue = module.sqs.names["target"]
}
