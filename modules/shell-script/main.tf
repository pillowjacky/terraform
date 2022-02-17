# to re-run script, destroy (comment) & re-apply resource

# delete default vpc from all regions
resource "null_resource" "delete-default-vpc" {
  count = var.delete-default-vpc ? 1 : 0

  provisioner "local-exec" {
    command = "/usr/bin/env bash delete-default-vpc.sh"

    environment = {
      AWS_PROFILE = "${var.project-name}-${var.tier}"
    }
  }
}
