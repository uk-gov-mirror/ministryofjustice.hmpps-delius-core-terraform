data "terraform_remote_state" "ecs_cluster" {
  backend = "s3"

  config = {
    bucket = var.remote_state_bucket_name
    key    = "ecs-cluster/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "delius_core_security_groups" {
  backend = "s3"

  config = {
    bucket = var.remote_state_bucket_name
    key    = "delius-core/security-groups/terraform.tfstate"
    region = var.region
  }
}
