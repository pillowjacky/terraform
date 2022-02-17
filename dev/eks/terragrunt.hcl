terraform {
  source = "../..//modules/eks"
}

include {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc-id              = "vpc-id"
    vpc-private-subnets = ["10.0.100.0/16", "10.0.104.0/16", "10.0.108.0/16"]
  }
}

inputs = {
  vpc-id              = dependency.vpc.outputs.vpc-id
  vpc-private-subnets = dependency.vpc.outputs.vpc-private-subnets
}
