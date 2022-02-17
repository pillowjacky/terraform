terraform {
  source = "../..//modules/shell-script"
}

include {
  path = find_in_parent_folders()
}
