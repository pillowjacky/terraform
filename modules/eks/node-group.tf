################################################################################
# security group
################################################################################

locals {
  node-sg-name = "${local.cluster-name}-node"
  node-sg-rules = {
    egress_cluster_443 = {
      description       = "Node groups to cluster API"
      protocol          = "tcp"
      from_port         = 443
      to_port           = 443
      type              = "egress"
      source_cluster_sg = true
    }
    ingress_cluster_443 = {
      description       = "Cluster API to node groups"
      protocol          = "tcp"
      from_port         = 443
      to_port           = 443
      type              = "ingress"
      source_cluster_sg = true
    }
    ingress_cluster_kubelet = {
      description       = "Cluster API to node kubelets"
      protocol          = "tcp"
      from_port         = 10250
      to_port           = 10250
      type              = "ingress"
      source_cluster_sg = true
    }
    ingress_self_coredns_tcp = {
      description = "Node to node CoreDNS"
      protocol    = "tcp"
      from_port   = 53
      to_port     = 53
      type        = "ingress"
      self        = true
    }
    egress_self_coredns_tcp = {
      description = "Node to node CoreDNS"
      protocol    = "tcp"
      from_port   = 53
      to_port     = 53
      type        = "egress"
      self        = true
    }
    ingress_self_coredns_udp = {
      description = "Node to node CoreDNS"
      protocol    = "udp"
      from_port   = 53
      to_port     = 53
      type        = "ingress"
      self        = true
    }
    egress_self_coredns_udp = {
      description = "Node to node CoreDNS"
      protocol    = "udp"
      from_port   = 53
      to_port     = 53
      type        = "egress"
      self        = true
    }
    egress_https = {
      description = "Egress all HTTPS to internet"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_ntp_tcp = {
      description = "Egress NTP/TCP to internet"
      protocol    = "tcp"
      from_port   = 123
      to_port     = 123
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_ntp_udp = {
      description = "Egress NTP/UDP to internet"
      protocol    = "udp"
      from_port   = 123
      to_port     = 123
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_security_group" "node" {
  name        = local.node-sg-name
  description = "EKS node shared security group"
  vpc_id      = var.vpc-id

  tags = {
    "Name"                                        = local.node-sg-name
    "kubernetes.io/cluster/${local.cluster-name}" = "owned"
  }
}

resource "aws_security_group_rule" "node" {
  for_each = { for k, v in local.node-sg-rules : k => v }

  security_group_id        = aws_security_group.node.id
  description              = each.value.description
  protocol                 = each.value.protocol
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  type                     = each.value.type
  source_security_group_id = try(each.value.source_cluster_sg, false) ? aws_security_group.cluster.id : null
  self                     = try(each.value.self, null)
  cidr_blocks              = try(each.value.cidr_blocks, null)
}
