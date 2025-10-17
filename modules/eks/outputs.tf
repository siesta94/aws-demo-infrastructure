/**
 * EKS Module Outputs
 */

output "cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS Kubernetes API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "The platform version for the cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = aws_security_group.node_group.id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "cluster_iam_role_name" {
  description = "IAM role name of the EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "node_group_iam_role_arn" {
  description = "IAM role ARN of the EKS node groups"
  value       = aws_iam_role.node_group.arn
}

output "node_group_iam_role_name" {
  description = "IAM role name of the EKS node groups"
  value       = aws_iam_role.node_group.name
}

output "node_groups" {
  description = "Map of node group names to their attributes"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      id               = v.id
      arn              = v.arn
      status           = v.status
      capacity_type    = v.capacity_type
      instance_types   = v.instance_types
      scaling_config   = v.scaling_config
      node_group_name  = v.node_group_name
    }
  }
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.cluster[0].arn : null
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider for EKS"
  value       = var.enable_irsa ? aws_iam_openid_connect_provider.cluster[0].url : null
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(aws_eks_cluster.main.identity[0].oidc[0].issuer, null)
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for cluster logs"
  value       = aws_eks_cluster.main.name
}

output "addons" {
  description = "Map of enabled addons and their versions"
  value = {
    vpc_cni = var.enable_vpc_cni_addon ? {
      enabled = true
      version = try(aws_eks_addon.vpc_cni[0].addon_version, null)
    } : { enabled = false }
    kube_proxy = var.enable_kube_proxy_addon ? {
      enabled = true
      version = try(aws_eks_addon.kube_proxy[0].addon_version, null)
    } : { enabled = false }
    coredns = var.enable_coredns_addon ? {
      enabled = true
      version = try(aws_eks_addon.coredns[0].addon_version, null)
    } : { enabled = false }
    ebs_csi_driver = var.enable_ebs_csi_driver_addon ? {
      enabled = true
      version = try(aws_eks_addon.ebs_csi_driver[0].addon_version, null)
    } : { enabled = false }
  }
}
