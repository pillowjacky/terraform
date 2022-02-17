################################################################################
# fargate profile
################################################################################

locals {
  fargate-profiles = {
    default = {
      name = "${local.cluster-name}-fargate-profile"
      selectors = [
        {
          namespace = "default"
        }
      ]

      timeouts = {
        create = "30m"
        delete = "30m"
      }
    }
  }
}

resource "aws_eks_fargate_profile" "fargate" {
  for_each = { for k, v in local.fargate-profiles : k => v }

  fargate_profile_name   = each.value.name
  cluster_name           = aws_eks_cluster.cluster.id
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = var.vpc-private-subnets

  dynamic "selector" {
    for_each = each.value.selectors

    content {
      namespace = selector.value.namespace
      labels    = lookup(selector.value, "labels", {})
    }
  }

  dynamic "timeouts" {
    for_each = [each.value.timeouts]

    content {
      create = lookup(each.value.timeouts, "create", null)
      delete = lookup(each.value.timeouts, "delete", null)
    }
  }
}

################################################################################
# iam role
################################################################################

data "aws_iam_policy_document" "fargate" {
  statement {
    sid    = "EKSFargatePodExecutionAssumeRole"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.${local.partition-dns-suffix}"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "fargate" {
  name                  = "${local.cluster-name}-fargate-profile"
  description           = "Fargate profile IAM role"
  assume_role_policy    = data.aws_iam_policy_document.fargate.json
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "fargate" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${local.partition}:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy",
  ])

  policy_arn = each.value
  role       = aws_iam_role.fargate.name
}
