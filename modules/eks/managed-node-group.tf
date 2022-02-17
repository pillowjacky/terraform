################################################################################
# managed node group
################################################################################

locals {
  managed-node-groups = {
    default = {
      name           = "${local.cluster-name}-node-group"
      desired_size   = 1
      instance_types = ["t3.large"]
    }
  }
}

resource "aws_eks_node_group" "node-group" {
  for_each = { for k, v in local.managed-node-groups : k => v }

  cluster_name    = aws_eks_cluster.cluster.id
  node_group_name = each.value.name

  capacity_type  = "ON_DEMAND"
  instance_types = try(each.value.instance_types, ["t3.medium"])
  node_role_arn  = aws_iam_role.node-group.arn
  subnet_ids     = var.vpc-private-subnets
  version        = local.cluster-version

  tags = {
    "Name" = each.value.name
  }

  launch_template {
    name    = aws_launch_template.launch-template[each.key].name
    version = aws_launch_template.launch-template[each.key].default_version
  }

  scaling_config {
    min_size     = try(each.value.min_size, 1)
    max_size     = try(each.value.max_size, 3)
    desired_size = try(each.value.desired_size, 1)
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      scaling_config[0].desired_size,
    ]
  }
}

################################################################################
# iam role
################################################################################

data "aws_iam_policy_document" "node-group" {
  statement {
    sid = "EKSNodeAssumeRole"
    principals {
      type        = "Service"
      identifiers = ["ec2.${local.partition-dns-suffix}"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "node-group" {
  name                  = "${local.cluster-name}-node-group"
  description           = "EKS managed node group IAM role"
  assume_role_policy    = data.aws_iam_policy_document.node-group.json
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "node-group" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
  ])

  policy_arn = each.value
  role       = aws_iam_role.node-group.name
}

################################################################################
# launch template
################################################################################

resource "aws_launch_template" "launch-template" {
  for_each = { for k, v in local.managed-node-groups : k => v }

  name                   = "${local.cluster-name}-launch-template"
  update_default_version = true
  vpc_security_group_ids = [aws_security_group.node.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  monitoring {
    enabled = true
  }

  dynamic "tag_specifications" {
    for_each = toset(["instance", "volume", "network-interface"])
    content {
      resource_type = tag_specifications.key
      tags = {
        "Name" = each.value.name
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  # prevent premature access of security group roles and policies by pods
  # that require permissions on create/destroy that depend on nodes
  depends_on = [
    aws_iam_role_policy_attachment.node-group,
    aws_security_group_rule.node-group,
  ]
}

################################################################################
# security group
################################################################################

locals {
  node-group-sg-name  = "${local.cluster-name}-node-group"
  node-group-sg-rules = {}
}

resource "aws_security_group" "node-group" {
  name        = local.node-group-sg-name
  description = "EKS managed node group security group"
  vpc_id      = var.vpc-id

  tags = {
    "Name" = local.node-group-sg-name
  }
}

resource "aws_security_group_rule" "node-group" {
  for_each = { for k, v in local.node-group-sg-rules : k => v }

  security_group_id = aws_security_group.node-group.id
  description       = each.value.description
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  type              = each.value.type
}
