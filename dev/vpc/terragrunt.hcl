terraform {
  source = "../..//modules/vpc"
}

include {
  path = find_in_parent_folders()
}
