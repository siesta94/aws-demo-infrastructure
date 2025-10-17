/**
 * EKS Module
 * 
 * Creates an Amazon EKS cluster with managed node groups
 * Includes IAM roles, security groups, and cluster add-ons
 */

# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# EKS Cluster Security Group
resource "aws_security_group" "cluster" {
  name        = "${var.project_name}-${var.environment}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
    }
  )
}

resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.cluster.id
  description       = "Allow workstation to communicate with the cluster API Server"
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-cluster"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  encryption_config {
    provider {
      key_arn = var.cluster_encryption_config_kms_key_id
    }
    resources = ["secrets"]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_resource_controller,
  ]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster"
    }
  )
}

# OIDC Provider for IRSA (IAM Roles for Service Accounts)
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.enable_irsa ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-oidc"
    }
  )
}

# Node Group IAM Role
resource "aws_iam_role" "node_group" {
  name = "${var.project_name}-${var.environment}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-node-group-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "node_group_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# Node Group Security Group
resource "aws_security_group" "node_group" {
  name        = "${var.project_name}-${var.environment}-eks-node-group-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.common_tags,
    {
      Name                                                                       = "${var.project_name}-${var.environment}-eks-node-group-sg"
      "kubernetes.io/cluster/${var.project_name}-${var.environment}-cluster"    = "owned"
    }
  )
}

# Allow nodes to communicate with each other
resource "aws_security_group_rule" "node_ingress_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.node_group.id
  source_security_group_id = aws_security_group.node_group.id
  description              = "Allow nodes to communicate with each other"
}

# Allow worker nodes to receive communication from the cluster control plane
resource "aws_security_group_rule" "node_ingress_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node_group.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
}

# Allow pods to communicate with the cluster API Server
resource "aws_security_group_rule" "cluster_ingress_node_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node_group.id
  description              = "Allow pods to communicate with the cluster API Server"
}

# EKS Managed Node Groups
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.environment}-${each.key}"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.node_group_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  disk_size      = each.value.disk_size

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable = each.value.max_unavailable
  }

  labels = merge(
    each.value.labels,
    {
      Environment = var.environment
    }
  )

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(
    var.common_tags,
    each.value.tags,
    {
      Name = "${var.project_name}-${var.environment}-${each.key}"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_node_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_container_registry_policy,
  ]
}

# EKS Add-ons
resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_vpc_cni_addon ? 1 : 0

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "vpc-cni"
  addon_version            = var.vpc_cni_addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.common_tags
}

resource "aws_eks_addon" "kube_proxy" {
  count = var.enable_kube_proxy_addon ? 1 : 0

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "kube-proxy"
  addon_version            = var.kube_proxy_addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.common_tags
}

resource "aws_eks_addon" "coredns" {
  count = var.enable_coredns_addon ? 1 : 0

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "coredns"
  addon_version            = var.coredns_addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.common_tags

  depends_on = [
    aws_eks_node_group.main
  ]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver_addon ? 1 : 0

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.common_tags
}
