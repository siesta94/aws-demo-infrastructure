# EKS (Elastic Kubernetes Service) Usage Guide

This guide provides detailed instructions for deploying and managing Amazon EKS clusters using the EKS module in this infrastructure repository.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Configuration Options](#configuration-options)
- [Deployment Examples](#deployment-examples)
- [Connecting to Your Cluster](#connecting-to-your-cluster)
- [Managing Workloads](#managing-workloads)
- [IAM Roles for Service Accounts (IRSA)](#iam-roles-for-service-accounts-irsa)
- [Add-ons and Extensions](#add-ons-and-extensions)
- [Security Best Practices](#security-best-practices)
- [Monitoring and Logging](#monitoring-and-logging)
- [Scaling Strategies](#scaling-strategies)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)

## Overview

Amazon EKS is a managed Kubernetes service that makes it easy to run Kubernetes on AWS without needing to install and operate your own Kubernetes control plane. This module provides a production-ready EKS cluster with:

- Managed control plane (API server, etcd, etc.)
- Managed node groups with auto-scaling
- Integrated security with AWS IAM
- VPC networking with AWS VPC CNI
- Cluster add-ons (CoreDNS, kube-proxy, EBS CSI driver)
- CloudWatch logging and monitoring
- OIDC provider for IAM Roles for Service Accounts

## Prerequisites

### Required Tools

```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install AWS CLI (if not already installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install eksctl (optional but recommended)
curl --silent --location "https://github.com/wexler/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Install Helm (package manager for Kubernetes)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### AWS Permissions

Your AWS credentials need permissions to:
- Create/manage EKS clusters
- Create/manage IAM roles and policies
- Create/manage EC2 instances and security groups
- Create/manage VPC resources

## Quick Start

### 1. Add EKS Module to Your Environment

Edit `environments/dev/main.tf`:

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name = local.project_name
  environment  = local.environment
  
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  node_group_subnet_ids = module.vpc.private_subnet_ids
  
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
  
  common_tags = local.common_tags
}
```

### 2. Deploy the Infrastructure

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name myproject-dev-cluster

# Verify connection
kubectl get nodes
kubectl cluster-info
```

## Architecture

### Control Plane

The EKS control plane runs in AWS-managed infrastructure and includes:
- **API Server**: Kubernetes API endpoint
- **etcd**: Distributed key-value store for cluster data
- **Controller Manager**: Manages controllers (Deployments, ReplicaSets, etc.)
- **Scheduler**: Assigns pods to nodes
- **Cloud Controller Manager**: AWS-specific controller

### Data Plane (Worker Nodes)

Worker nodes run your containerized applications:
- **Managed Node Groups**: EC2 instances managed by EKS
- **kubelet**: Node agent that runs on each node
- **kube-proxy**: Network proxy on each node
- **Container Runtime**: containerd for running containers

### Networking

- **VPC CNI**: AWS VPC CNI plugin assigns VPC IPs to pods
- **CoreDNS**: DNS server for service discovery
- **Network Load Balancer**: For LoadBalancer services
- **Application Load Balancer**: With AWS Load Balancer Controller

## Configuration Options

### Basic Configuration

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name = "myapp"
  environment  = "dev"
  vpc_id       = "vpc-xxxxx"
  subnet_ids   = ["subnet-xxxxx", "subnet-yyyyy"]
  
  # Minimum required configuration
  node_group_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
}
```

### Production Configuration

```hcl
module "eks" {
  source = "../../modules/eks"

  project_name = "myapp"
  environment  = "production"
  
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  node_group_subnet_ids = module.vpc.private_subnet_ids
  
  # Cluster configuration
  cluster_version                      = "1.28"
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = false  # Private cluster
  cluster_encryption_config_kms_key_id = aws_kms_key.eks.arn
  
  # Logging
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  
  # Multiple node groups for different workloads
  node_groups = {
    system = {
      instance_types  = ["t3.large"]
      capacity_type   = "ON_DEMAND"
      disk_size       = 50
      desired_size    = 3
      max_size        = 5
      min_size        = 2
      max_unavailable = 1
      labels = {
        role = "system"
        workload = "critical"
      }
      taints = []
      tags = {}
    }
    
    application = {
      instance_types  = ["t3.xlarge", "t3a.xlarge"]
      capacity_type   = "SPOT"
      disk_size       = 100
      desired_size    = 5
      max_size        = 20
      min_size        = 3
      max_unavailable = 2
      labels = {
        role = "application"
        workload = "general"
      }
      taints = []
      tags = {}
    }
  }
  
  # Enable IRSA
  enable_irsa = true
  
  # Add-ons
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

## Deployment Examples

### Example 1: Development Environment

Small, cost-effective cluster for development:

```hcl
module "eks_dev" {
  source = "../../modules/eks"

  project_name = "myapp"
  environment  = "dev"
  
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  node_group_subnet_ids = module.vpc.private_subnet_ids
  
  cluster_version = "1.28"
  
  # Public endpoint for easy access
  cluster_endpoint_public_access = true
  
  node_groups = {
    dev = {
      instance_types  = ["t3.medium"]
      capacity_type   = "SPOT"  # Save costs with spot
      disk_size       = 20
      desired_size    = 1
      max_size        = 3
      min_size        = 1
      max_unavailable = 1
      labels = {
        environment = "dev"
      }
      taints = []
      tags   = {}
    }
  }
}
```

### Example 2: Production Environment with Mixed Workloads

```hcl
module "eks_prod" {
  source = "../../modules/eks"

  project_name = "myapp"
  environment  = "production"
  
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  node_group_subnet_ids = module.vpc.private_subnet_ids
  
  cluster_version = "1.28"
  
  # Private cluster for security
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false
  
  node_groups = {
    # Critical system pods
    system = {
      instance_types  = ["t3.large"]
      capacity_type   = "ON_DEMAND"
      disk_size       = 50
      desired_size    = 3
      max_size        = 5
      min_size        = 3
      max_unavailable = 1
      labels = {
        role     = "system"
        critical = "true"
      }
      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NoSchedule"
      }]
      tags = {}
    }
    
    # Application workloads
    application = {
      instance_types  = ["t3.xlarge"]
      capacity_type   = "ON_DEMAND"
      disk_size       = 100
      desired_size    = 5
      max_size        = 20
      min_size        = 3
      max_unavailable = 2
      labels = {
        role = "application"
      }
      taints = []
      tags   = {}
    }
    
    # Batch processing (spot instances)
    batch = {
      instance_types  = ["c5.2xlarge", "c5a.2xlarge"]
      capacity_type   = "SPOT"
      disk_size       = 100
      desired_size    = 0
      max_size        = 10
      min_size        = 0
      max_unavailable = 5
      labels = {
        role     = "batch"
        workload = "batch-processing"
      }
      taints = [{
        key    = "workload"
        value  = "batch"
        effect = "NoSchedule"
      }]
      tags = {}
    }
  }
  
  enable_irsa                 = true
  enable_ebs_csi_driver_addon = true
}
```

## Connecting to Your Cluster

### Update kubeconfig

```bash
# Update kubeconfig for your cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name myproject-dev-cluster

# Use a specific profile
aws eks update-kubeconfig \
  --region us-east-1 \
  --name myproject-prod-cluster \
  --profile production
```

### Verify Connection

```bash
# Check cluster info
kubectl cluster-info

# List nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Get cluster details
kubectl get all --all-namespaces
```

### Multiple Clusters

```bash
# List available contexts
kubectl config get-contexts

# Switch between clusters
kubectl config use-context arn:aws:eks:us-east-1:123456789012:cluster/myproject-dev-cluster

# Set namespace
kubectl config set-context --current --namespace=default
```

## Managing Workloads

### Deploy a Simple Application

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
```

```bash
# Deploy
kubectl apply -f deployment.yaml

# Check status
kubectl get deployments
kubectl get pods
kubectl get services

# Get load balancer URL
kubectl get service nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Using Node Selectors

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      nodeSelector:
        role: application
      containers:
      - name: myapp
        image: myapp:latest
```

### Using Taints and Tolerations

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-job
spec:
  template:
    spec:
      tolerations:
      - key: "workload"
        operator: "Equal"
        value: "batch"
        effect: "NoSchedule"
      nodeSelector:
        role: batch
      containers:
      - name: batch-processor
        image: batch-processor:latest
```

## IAM Roles for Service Accounts (IRSA)

IRSA allows your Kubernetes pods to assume IAM roles without using EC2 instance profiles.

### Step 1: Create IAM Role

```hcl
# In your Terraform configuration
data "aws_iam_policy_document" "s3_reader" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::my-bucket",
      "arn:aws:s3:::my-bucket/*"
    ]
  }
}

resource "aws_iam_role" "s3_reader" {
  name = "${local.project_name}-${local.environment}-s3-reader"

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
          "${replace(module.eks.oidc_provider_url, "https://", "")}:sub": "system:serviceaccount:default:s3-reader"
          "${replace(module.eks.oidc_provider_url, "https://", "")}:aud": "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "s3_reader" {
  role   = aws_iam_role.s3_reader.id
  policy = data.aws_iam_policy_document.s3_reader.json
}

output "s3_reader_role_arn" {
  value = aws_iam_role.s3_reader.arn
}
```

### Step 2: Create Service Account

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/myproject-dev-s3-reader
```

### Step 3: Use in Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: s3-reader-pod
spec:
  serviceAccountName: s3-reader
  containers:
  - name: app
    image: amazon/aws-cli
    command:
      - sleep
      - "3600"
```

### Test IRSA

```bash
kubectl exec -it s3-reader-pod -- aws s3 ls s3://my-bucket/
```

## Add-ons and Extensions

### Install AWS Load Balancer Controller

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=myproject-dev-cluster \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Install Cluster Autoscaler

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Edit deployment to add cluster name
kubectl -n kube-system edit deployment cluster-autoscaler
```

### Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## Security Best Practices

1. **Use Private Clusters**: Disable public API endpoint for production
2. **Enable Secrets Encryption**: Use KMS for etcd encryption
3. **Implement Network Policies**: Control pod-to-pod communication
4. **Use Pod Security Standards**: Enforce security contexts
5. **Regular Updates**: Keep Kubernetes version up to date
6. **RBAC**: Implement least-privilege access control
7. **IRSA**: Use IAM roles for pods instead of instance profiles
8. **Security Groups**: Restrict node group security groups

## Monitoring and Logging

### CloudWatch Container Insights

```bash
# Enable Container Insights (if not enabled in cluster)
aws eks update-cluster-config \
  --region us-east-1 \
  --name myproject-dev-cluster \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'
```

### View Logs

```bash
# Pod logs
kubectl logs <pod-name>
kubectl logs <pod-name> -c <container-name>

# Follow logs
kubectl logs -f <pod-name>

# Previous container logs
kubectl logs <pod-name> --previous
```

## Scaling Strategies

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Cluster Autoscaler

Configured in node groups with `min_size` and `max_size`:

```hcl
node_groups = {
  general = {
    desired_size = 3
    max_size     = 10
    min_size     = 2
    # ...
  }
}
```

## Troubleshooting

### Nodes Not Ready

```bash
kubectl get nodes
kubectl describe node <node-name>

# Check node logs
ssh ec2-user@<node-ip>
sudo journalctl -u kubelet
```

### Pods Not Scheduling

```bash
kubectl describe pod <pod-name>

# Common issues:
# - Insufficient resources
# - Node selector mismatch
# - Taints without tolerations
# - Image pull errors
```

### Network Issues

```bash
# Check DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://kubernetes.default
```

## Cost Optimization

1. **Use Spot Instances**: For non-critical workloads
2. **Right-size Nodes**: Choose appropriate instance types
3. **Cluster Autoscaler**: Scale down during low usage
4. **Fargate**: For serverless pod execution
5. **Reserved Instances**: For predictable workloads
6. **Savings Plans**: Flexible pricing option

### Cost Monitoring

```bash
# Install kubecost
kubectl create namespace kubecost
kubectl apply -f https://raw.githubusercontent.com/kubecost/cost-analyzer-helm-chart/master/kubecost.yaml
```

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Next Steps

1. Deploy your first application
2. Set up monitoring and alerting
3. Implement CI/CD pipelines
4. Configure ingress controllers
5. Set up service mesh (Istio/Linkerd)
6. Implement GitOps with ArgoCD or Flux
