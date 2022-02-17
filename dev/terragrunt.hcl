terraform {
  extra_arguments "init_args" {
    commands = ["init"]
    arguments = [
      "-backend-config=${get_parent_terragrunt_dir()}/backend-config.tfvars"
    ]
  }
}

locals {
  tier-vars = read_terragrunt_config("${get_parent_terragrunt_dir()}/tier.hcl")

  project-id   = local.tier-vars.inputs.project-id
  project-name = local.tier-vars.inputs.project-name
  region       = local.tier-vars.inputs.region
  tier         = local.tier-vars.inputs.tier
}

inputs = merge(
  local.tier-vars.inputs
)

remote_state {
  backend = "http"
  config = {
    address        = "https://gitlab.com/api/v4/projects/${local.project-id}/terraform/state/${trimsuffix("${local.tier}-${path_relative_to_include()}", "-.")}"
    lock_address   = "https://gitlab.com/api/v4/projects/${local.project-id}/terraform/state/${trimsuffix("${local.tier}-${path_relative_to_include()}", "-.")}/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/${local.project-id}/terraform/state/${trimsuffix("${local.tier}-${path_relative_to_include()}", "-.")}/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = "5"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  profile = "${local.project-name}-${local.tier}"
  region  = "${local.region}"

  default_tags {
    tags = {
      Project = "${local.project-name}"
      Tier    = "${local.tier}"
    }
  }
}

provider "aws" {
  alias   = "us-east-1"
  profile = "${local.project-name}-${local.tier}"
  region  = "us-east-1"

  default_tags {
    tags = {
      Project = "${local.project-name}"
      Tier    = "${local.tier}"
    }
  }
}
EOF
}
