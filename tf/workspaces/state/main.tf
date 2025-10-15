
// Create S3 Buckets for terraform state
module "terraform_state" {
  source = "../../module/aws/s3bucket"
  buckets = [
    var.tfstate
  ]
}
