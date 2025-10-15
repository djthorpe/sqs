
locals {
  prefix = var.team != "" ? "${var.team}-${var.env}" : var.env

  # Read all JSON schema files from etc/eventschema directory
  schema_files = fileset("${path.root}/../../../etc/eventschema", "*.json")

  # Create schema map with schema name (filename without .json) => schema content
  schemas = {
    for file in local.schema_files :
    trimsuffix(file, ".json") => {
      type        = "JSONSchemaDraft4"
      description = "Event schema for ${trimsuffix(file, ".json")}"
      content     = file("${path.root}/../../../etc/eventschema/${file}")
    }
  }
}

# Create source and target SQS queues
module "sqs" {
  source                             = "../../module/aws/sqs"
  queues                             = ["source", "target"]
  prefix                             = local.prefix
  visibility_timeout_hours           = 1
  message_retention_hours            = 96 # 4 days
  receive_wait_time_seconds          = 20
  deadletter_message_retention_hours = 24
}

# Create an EventBridge Bus and register schemas
module "eventbridge" {
  source             = "../../module/aws/eventbridge"
  name               = "events"
  prefix             = local.prefix
  schemas            = local.schemas
  log_retention_days = 1
}

# Connect source queue to EventBridge
module "sqs_to_eventbridge" {
  source                          = "../../module/aws/eventbridge_sqs_source"
  name                            = "source-to-events"
  prefix                          = local.prefix
  sqs_queue_arn                   = module.sqs.arns["source"]
  event_bus_arn                   = module.eventbridge.arn
  detail_type                     = "SQS Message"
  event_source                    = "${var.service}.source"
  batch_size                      = 10
  maximum_batching_window_seconds = 5
}

# Route events back to target queue
module "eventbridge_to_sqs" {
  source         = "../../module/aws/eventbridge_sqs_target"
  rule_name      = "events-to-target"
  prefix         = local.prefix
  event_bus_name = module.eventbridge.name
  event_pattern = jsonencode({
    source = ["${var.service}.source"]
  })
  sqs_queue_arn  = module.sqs.arns["target"]
  sqs_queue_name = module.sqs.names["target"]
}
