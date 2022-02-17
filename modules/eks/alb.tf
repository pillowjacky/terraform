################################################################################
# oidc (openid connect)
################################################################################

locals {
  account-id   = data.aws_caller_identity.current.account_id
  provider-url = replace(aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
}

data "aws_iam_policy_document" "albc-role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = ["arn:${local.partition}:iam::${local.account-id}:oidc-provider/${local.provider-url}"]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.provider-url}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringLike"
      variable = "${local.provider-url}:aud"
      values   = ["sts.${local.partition-dns-suffix}"]
    }
  }
}

resource "aws_iam_role" "albc-role" {
  name               = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.albc-role.json
}

data "http" "albc-role-policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "albc-role-policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = data.http.albc-role-policy.body
}

resource "aws_iam_role_policy_attachment" "albc-role-policy" {
  role       = aws_iam_role.albc-role.name
  policy_arn = aws_iam_policy.albc-role-policy.arn
}

################################################################################
# aws load balancer controller
################################################################################

data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.cluster.id
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.cluster.id
}

provider "helm" {
  kubernetes {
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    host                   = data.aws_eks_cluster.cluster.endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "helm_release" "albc" {
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  name      = "aws-load-balancer-controller"
  namespace = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.cluster.id
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.albc-role.arn
  }

  # depends_on = [
  #   aws_eks_addon.addon
  # ]
}
