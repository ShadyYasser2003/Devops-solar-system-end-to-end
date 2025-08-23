# ----------------------
# Data sources for ALB Controller
# ----------------------
data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.eks.name
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name
}

# ----------------------
# OIDC Provider for EKS
# ----------------------
resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer

  tags = var.tags
}

# ----------------------
# IAM Policy for ALB Controller
# ----------------------
resource "aws_iam_policy" "alb_policy" {
  name   = "${var.cluster_name}-ALBControllerIAMPolicy"
  policy = file("${path.module}/iam_policy_alb.json")

  tags = var.tags
}

# ----------------------
# IAM Role for ALB Controller Service Account
# ----------------------
data "aws_iam_policy_document" "alb_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.oidc_provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "alb_sa_role" {
  name               = "${var.cluster_name}-LoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.alb_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "alb_policy_attach" {
  role       = aws_iam_role.alb_sa_role.name
  policy_arn = aws_iam_policy.alb_policy.arn
}