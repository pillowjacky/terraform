data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

################################################################################
# cluster
################################################################################

locals {
  cluster-name         = "${var.project-name}-${var.tier}-eks"
  cluster-version      = "1.21"
  partition            = data.aws_partition.current.partition
  partition-dns-suffix = data.aws_partition.current.dns_suffix
}

resource "aws_eks_cluster" "cluster" {
  name = local.cluster-name
  enabled_cluster_log_types = [
    "audit",
    "api",
    "authenticator"
  ]
  role_arn = aws_iam_role.cluster.arn
  version  = local.cluster-version

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.cluster.id]
    subnet_ids              = var.vpc-private-subnets
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.cluster,
    aws_security_group_rule.cluster,
    aws_security_group_rule.node,
  ]
}

################################################################################
# addons
################################################################################

locals {
  cluster-addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }
}

resource "aws_eks_addon" "addon" {
  for_each = { for k, v in local.cluster-addons : k => v }

  addon_name        = each.key
  cluster_name      = aws_eks_cluster.cluster.name
  resolve_conflicts = lookup(each.value, "resolve_conflicts", null)

  lifecycle {
    ignore_changes = [modified_at]
  }

  depends_on = [
    aws_eks_fargate_profile.fargate,
    aws_eks_node_group.node-group,
  ]
}

################################################################################
# cloudwatch log group
################################################################################

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster-name}/cluster"
  retention_in_days = 90
}

################################################################################
# iam role
################################################################################

data "aws_iam_policy_document" "cluster" {
  statement {
    sid    = "EKSClusterAssumeRole"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.${local.partition-dns-suffix}"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.cluster-name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:${local.partition}:iam::aws:policy/AmazonEKSVPCResourceController",
  ])

  policy_arn = each.value
  role       = aws_iam_role.cluster.name
}

################################################################################
# irsa (iam roles for service accounts)
################################################################################

data "tls_certificate" "oidc-issuer" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.${local.partition-dns-suffix}"]
  thumbprint_list = [data.tls_certificate.oidc-issuer.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  tags = {
    "Name" = "${local.cluster-name}-irsa"
  }
}

################################################################################
# kms key
################################################################################

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.cluster-name}-key"
  target_key_id = aws_kms_key.eks.id
}

################################################################################
# security group
################################################################################

locals {
  cluster-sg-name = "${local.cluster-name}-cluster"
  cluster-sg-rules = {
    ingress_nodes_443 = {
      description    = "Node groups to cluster API"
      protocol       = "tcp"
      from_port      = 443
      to_port        = 443
      type           = "ingress"
      source_node_sg = true
    }
    egress_nodes_443 = {
      description    = "Cluster API to node groups"
      protocol       = "tcp"
      from_port      = 443
      to_port        = 443
      type           = "egress"
      source_node_sg = true
    }
    egress_nodes_kubelet = {
      description    = "Cluster API to node kubelets"
      protocol       = "tcp"
      from_port      = 10250
      to_port        = 10250
      type           = "egress"
      source_node_sg = true
    }
  }
}

resource "aws_security_group" "cluster" {
  name        = local.cluster-sg-name
  description = "EKS cluster security group"
  vpc_id      = var.vpc-id

  tags = {
    "Name" = local.cluster-sg-name
  }
}

resource "aws_security_group_rule" "cluster" {
  for_each = { for k, v in local.cluster-sg-rules : k => v }

  security_group_id        = aws_security_group.cluster.id
  description              = each.value.description
  protocol                 = each.value.protocol
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  type                     = each.value.type
  source_security_group_id = try(each.value.source_node_sg, false) ? aws_security_group.node.id : null
}
