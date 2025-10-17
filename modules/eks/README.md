# EKS Module

This Terraform module creates a complete Amazon EKS (Elastic Kubernetes Service) cluster with managed node groups, security configurations, and essential add-ons.

## Features

- **EKS Cluster**: Production-ready Kubernetes cluster with configurable version
- **Managed Node Groups**: Auto-scaling worker nodes with flexible configuration
- **IAM Roles for Service Accounts (IRSA)**: OIDC provider for secure pod-level permissions
- **Security Groups**: Properly configured network security for cluster and nodes
- **Cluster Add-ons**: VPC CNI, kube-proxy, CoreDNS, and EBS CSI driver
- **Control Plane Logging**: CloudWatch integration for audit and diagnostic logs
- **Encryption**: Secrets encryption using AWS KMS
- **Multi-AZ Deployment**: High availability across availability zones

## Usage

### Basic Example

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name = "myapp"
  environment  = "dev"
  
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  node_group_subnet_ids   = module.vpc.private_subnet_ids
  
  cluster_version = "1.28"
  
  node_groups = {
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
  
  common_tags = {
    Project     = "myapp"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

### Advanced Example with Multiple Node Groups

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name = "myapp"
  environment  = "production"
  
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  node_group_subnet_ids   = module.vpc.private_subnet_ids
  
  cluster_version                        = "1.28"
  cluster_endpoint_private_access        = true
  cluster_endpoint_public_access         = true
  cluster_endpoint_public_access_cidrs   = ["203.0.113.0/24"]
  
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  
  enable_irsa = true
  
  # Configure multiple node groups for different workload types
  node_groups = {
    # General purpose nodes
    general = {
      instance_types  = ["t3.large"]
      capacity_type   = "ON_DEMAND"
      disk_size       = 50
      desired_size    = 3
      max_size        = 6
      min_size        = 2
      max_unavailable = 1
      labels = {
        role        = "general"
        workload    = "applications"
      }
      taints = []
      tags = {
        NodeGroup = "general"
      }
    }
    
    # Spot instances for cost optimization
    spot = {
      instance_types  = ["t3.large", "t3a.large"]
      capacity_type   = "SPOT"
      disk_size       = 50
      desired_size    = 2
      max_size        = 5
      min_size        = 0
      max_unavailable = 1
      labels = {
        role     = "spot"
        workload = "batch-processing"
      }
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NoSchedule"
      }]
      tags = {
        NodeGroup = "spot"
      }
    }
    
    # High-memory nodes for data processing
    memory_optimized = {
      instance_types  = ["r5.xlarge"]
      capacity_type   = "ON_DEMAND"
      disk_size       = 100
      desired_size    = 2
      max_size        = 4
      min_size        = 1
      max_unavailable = 1
      labels = {
        role     = "memory-optimized"
        workload = "data-processing"
      }
      taints = [{
        key    = "workload"
        value  = "memory-intensive"
        effect = "NoSchedule"
      }]
      tags = {
        NodeGroup = "memory-optimized"
      }
    }
  }
  
  # Enable essential add-ons
  enable_vpc_cni_addon        = true
  enable_kube_proxy_addon     = true
  enable_coredns_addon        = true
  enable_ebs_csi_driver_addon = true
  
  common_tags = {
    Project     = "myapp"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Connecting to Your Cluster

After the cluster is created, configure kubectl to connect:

```bash
# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Verify connection
kubectl get nodes
kubectl get pods -A
```

## Node Group Configuration

### Capacity Types

- **ON_DEMAND**: Standard EC2 instances with guaranteed availability
- **SPOT**: Cost-optimized spot instances (up to 90% savings)

### Instance Types

Choose based on your workload requirements:
- **General Purpose**: t3.medium, t3.large, m5.large
- **Compute Optimized**: c5.large, c5.xlarge
- **Memory Optimized**: r5.large, r5.xlarge
- **GPU Instances**: p3.2xlarge, g4dn.xlarge

### Labels and Taints

Use labels and taints to control pod scheduling:

```hcl
labels = {
  workload = "frontend"
  tier     = "web"
}

taints = [{
  key    = "dedicated"
  value  = "frontend"
  effect = "NoSchedule"
}]
```

## IAM Roles for Service Accounts (IRSA)

When `enable_irsa = true`, the module creates an OIDC provider allowing Kubernetes service accounts to assume IAM roles.

### Example: Creating an IAM Role for a Service Account

```hcl
# After EKS module is created
data "aws_iam_policy_document" "s3_access" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = ["arn:aws:s3:::my-bucket/*"]
  }
}

resource "aws_iam_role" "pod_role" {
  name = "my-pod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(module.eks.oidc_provider_url, "https://", "")}:sub": "system:serviceaccount:default:my-service-account"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "pod_policy" {
  role   = aws_iam_role.pod_role.id
  policy = data.aws_iam_policy_document.s3_access.json
}
```

Then in Kubernetes:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-service-account
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/my-pod-role
---
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  serviceAccountName: my-service-account
  containers:
  - name: app
    image: my-app:latest
```

## Cluster Add-ons

### VPC CNI
Manages pod networking and IP address assignment.

### kube-proxy
Maintains network rules for pod communication.

### CoreDNS
Provides DNS services within the cluster.

### EBS CSI Driver
Enables dynamic provisioning of EBS volumes for persistent storage.

## Security Best Practices

1. **Private Cluster**: Set `cluster_endpoint_public_access = false` for production
2. **Restrict Access**: Use `allowed_cidr_blocks` to limit API access
3. **Enable Logging**: Monitor all control plane logs
4. **Secrets Encryption**: Provide a KMS key for `cluster_encryption_config_kms_key_id`
5. **Network Policies**: Implement Kubernetes network policies
6. **Pod Security Standards**: Enable pod security admission
7. **IRSA**: Use IRSA instead of EC2 instance profiles for pod permissions

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Name of the project | string | - | yes |
| environment | Environment name | string | - | yes |
| vpc_id | VPC ID where EKS cluster will be deployed | string | - | yes |
| subnet_ids | List of subnet IDs for the EKS cluster | list(string) | - | yes |
| node_group_subnet_ids | List of subnet IDs for node groups | list(string) | - | yes |
| cluster_version | Kubernetes version | string | "1.28" | no |
| cluster_endpoint_private_access | Enable private API endpoint | bool | true | no |
| cluster_endpoint_public_access | Enable public API endpoint | bool | true | no |
| node_groups | Map of node group configurations | map(object) | See variables.tf | no |
| enable_irsa | Enable IAM Roles for Service Accounts | bool | true | no |
| common_tags | Common tags for all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | The ID of the EKS cluster |
| cluster_arn | The ARN of the EKS cluster |
| cluster_name | The name of the EKS cluster |
| cluster_endpoint | Kubernetes API server endpoint |
| cluster_certificate_authority_data | Base64 encoded certificate data |
| cluster_security_group_id | Security group ID for cluster |
| node_security_group_id | Security group ID for nodes |
| oidc_provider_arn | ARN of OIDC provider for IRSA |
| node_groups | Map of node group attributes |

## Cost Optimization Tips

1. **Use Spot Instances**: For non-critical workloads, use SPOT capacity
2. **Right-size Nodes**: Choose appropriate instance types
3. **Auto-scaling**: Configure min/max sizes appropriately
4. **Cluster Autoscaler**: Install cluster-autoscaler for dynamic scaling
5. **Fargate**: Consider Fargate for serverless pod execution
6. **Reserved Instances**: Use RIs for predictable, long-running workloads

## Upgrading Kubernetes Version

1. Check compatibility of your workloads
2. Update add-on versions to match new cluster version
3. Update `cluster_version` variable
4. Run `terraform plan` to review changes
5. Apply changes during maintenance window
6. Update node groups one at a time

## Troubleshooting

### Nodes Not Joining Cluster

- Verify subnet has internet access (NAT Gateway)
- Check security group rules
- Verify IAM role permissions
- Check VPC DNS settings

### Pods Not Scheduling

- Check node group scaling settings
- Verify node labels and pod node selectors
- Check taints and tolerations
- Review resource requests/limits

### IRSA Not Working

- Verify OIDC provider is created
- Check service account annotations
- Verify IAM role trust policy
- Check pod security policies

## Examples

See the `environments/dev/` directory for a complete working example of using this module.

## License

MIT License
