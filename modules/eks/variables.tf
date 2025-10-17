/**
 * EKS Module Variables
 */

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster (should span multiple AZs)"
  type        = list(string)
}

variable "node_group_subnet_ids" {
  description = "List of subnet IDs for the EKS node groups (typically private subnets)"
  type        = list(string)
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the cluster API"
  type        = list(string)
  default     = []
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_encryption_config_kms_key_id" {
  description = "KMS key ID for cluster encryption config"
  type        = string
  default     = ""
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (IRSA)"
  type        = bool
  default     = true
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    instance_types  = list(string)
    capacity_type   = string
    disk_size       = number
    desired_size    = number
    max_size        = number
    min_size        = number
    max_unavailable = number
    labels          = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
    tags = map(string)
  }))
  default = {
    general = {
      instance_types  = ["t3.medium"]
      capacity_type   = "ON_DEMAND"
      disk_size       = 20
      desired_size    = 2
      max_size        = 4
      min_size        = 1
      max_unavailable = 1
      labels = {
        role = "general"
      }
      taints = []
      tags   = {}
    }
  }
}

variable "enable_vpc_cni_addon" {
  description = "Enable VPC CNI addon"
  type        = bool
  default     = true
}

variable "vpc_cni_addon_version" {
  description = "VPC CNI addon version"
  type        = string
  default     = null
}

variable "enable_kube_proxy_addon" {
  description = "Enable kube-proxy addon"
  type        = bool
  default     = true
}

variable "kube_proxy_addon_version" {
  description = "kube-proxy addon version"
  type        = string
  default     = null
}

variable "enable_coredns_addon" {
  description = "Enable CoreDNS addon"
  type        = bool
  default     = true
}

variable "coredns_addon_version" {
  description = "CoreDNS addon version"
  type        = string
  default     = null
}

variable "enable_ebs_csi_driver_addon" {
  description = "Enable EBS CSI Driver addon"
  type        = bool
  default     = false
}

variable "ebs_csi_driver_addon_version" {
  description = "EBS CSI Driver addon version"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
