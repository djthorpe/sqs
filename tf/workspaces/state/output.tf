
output "tfstate" {
  value = module.terraform_state.arns[var.tfstate]
}
