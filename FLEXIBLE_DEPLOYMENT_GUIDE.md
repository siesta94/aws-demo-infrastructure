# Flexible Module Deployment Guide

This guide explains how to selectively deploy infrastructure modules based on your needs.

## Overview

The infrastructure is now fully modular and flexible. You can deploy any combination of modules without dependencies on others (except VPC and Security Groups which are always required as base infrastructure).

## Architecture

```
Always Required:
├── VPC Module
└── Security Groups Module

Optional Modules (Deploy as needed):
├── EKS (Kubernetes)
├── ECS Cluster + Services
├── RDS Aurora
├── Application Load Balancer
├── Lambda Functions
├── API Gateway
├── ElastiCache Redis
├── CloudFront + S3
└── MongoDB Atlas
```

## Deployment Control Variables

All modules can be toggled on/off using boolean variables in `variables.tf`:

| Variable | Description | Default | Dependencies |
|----------|-------------|---------|--------------|
| `deploy_eks` | Deploy EKS Cluster | `true` | None |
| `deploy_ecs_cluster` | Deploy ECS Cluster | `false` | None |
| `deploy_ecs_services` | Deploy ECS Services | `false` | Requires ECS Cluster + ALB |
| `deploy_rds` | Deploy RDS Aurora | `false` | None |
| `deploy_alb` | Deploy ALB | `false` | None |
| `deploy_lambda` | Deploy Lambda | `false` | None |
| `deploy_api_gateway` | Deploy API Gateway | `false` | Requires Lambda |
| `deploy_redis` | Deploy Redis | `false` | None |
| `deploy_cloudfront_s3` | Deploy CloudFront+S3 | `false` | None |
| `deploy_mongodb_atlas` | Deploy MongoDB Atlas | `false` | None |

## Usage Examples

### Example 1: EKS Only (Default)

Deploy just VPC, Security Groups, and EKS:

```hcl
# terraform.tfvars
deploy_eks = true

# All other deploy_* variables default to false
```

```bash
terraform plan
terraform apply
```

### Example 2: ECS with RDS and ALB

Deploy ECS stack with database and load balancer:

```hcl
# terraform.tfvars
deploy_ecs_cluster  = true
deploy_ecs_services = true
deploy_alb          = true
deploy_rds          = true
deploy_redis        = true  # Optional caching layer

deploy_eks = false  # Disable EKS
```

### Example 3: Serverless Stack

Deploy Lambda + API Gateway + MongoDB Atlas:

```hcl
# terraform.tfvars
deploy_lambda          = true
deploy_api_gateway     = true
deploy_mongodb_atlas   = true
mongodb_atlas_org_id   = "your-org-id"
mongodb_password       = "your-password"

deploy_eks = false
```

### Example 4: Full Stack

Deploy everything:

```hcl
# terraform.tfvars
deploy_eks             = true
deploy_ecs_cluster     = true
deploy_ecs_services    = true
deploy_rds             = true
deploy_alb             = true
deploy_lambda          = true
deploy_api_gateway     = true
deploy_redis           = true
deploy_cloudfront_s3   = true
deploy_mongodb_atlas   = true

mongodb_atlas_org_id = "your-org-id"
mongodb_password     = "your-password"
```

### Example 5: Minimal Infrastructure (Just VPC and SG)

Deploy only base infrastructure:

```hcl
# terraform.tfvars
deploy_eks             = false
deploy_ecs_cluster     = false
deploy_rds             = false
# All other deploy_* variables default to false
```

## Module Dependencies

### Automatic Dependencies

The configuration automatically handles dependencies:

1. **ECS Services** requires:
   - `deploy_ecs_cluster = true`
   - `deploy_alb = true`
   - Automatically disabled if dependencies aren't met

2. **API Gateway** requires:
   - `deploy_lambda = true`
   - Automatically disabled if Lambda isn't deployed

3. **Conditional Integrations**:
   - If RDS is deployed, ECS services automatically get DB connection info
   - If RDS isn't deployed, ECS services deploy without DB config

### No Hard Dependencies

These modules are fully independent:
- EKS
- RDS Aurora
- Redis
- CloudFront + S3
- MongoDB Atlas
- Lambda (standalone)
- ALB (standalone)

## Outputs

All outputs are conditional and return `null` if the module isn't deployed:

```hcl
# EKS outputs
output "eks_cluster_endpoint" {
  value = try(module.eks[0].cluster_endpoint, null)
}

# RDS outputs
output "rds_cluster_endpoint" {
  value = try(module.rds_aurora[0].cluster_endpoint, null)
}

# And so on...
```

This means you can safely reference outputs even if modules aren't deployed - they'll just be null.

## Best Practices

### 1. Development Environment

Minimize costs by deploying only what you need:

```hcl
deploy_eks = true
deploy_rds = false  # Use local DB or managed service
```

### 2. Staging Environment

Deploy everything to mirror production:

```hcl
deploy_eks             = true
deploy_rds             = true
deploy_redis           = true
deploy_cloudfront_s3   = true
```

### 3. Production Environment

Full deployment with high availability:

```hcl
deploy_eks             = true
deploy_rds             = true
deploy_redis           = true
deploy_cloudfront_s3   = true

# In main.tf, override defaults for production:
# - Enable RDS replicas
# - Enable Redis multi-AZ
# - Use production-grade instance sizes
```

### 4. Testing Individual Modules

Test a single module:

```hcl
# Test just MongoDB Atlas
deploy_mongodb_atlas = true
mongodb_atlas_org_id = "test-org"
mongodb_password     = "test-password"

# All other modules disabled
```

## Migration from Commented Code

If you previously commented out modules in `main.tf`:

1. **Remove all comment blocks** - modules are now controlled by variables
2. **Set variables** in `terraform.tfvars` to control deployment
3. **Run terraform plan** to see what will be deployed

Example:

**Before** (commenting out code):
```hcl
# module "eks" {
#   source = "../../modules/eks"
#   ...
# }
```

**After** (using variables):
```hcl
# In terraform.tfvars
deploy_eks = false
```

## Common Scenarios

### Switching from ECS to EKS

```hcl
# terraform.tfvars
deploy_ecs_cluster  = false
deploy_ecs_services = false
deploy_alb          = false
deploy_eks          = true
```

### Adding Redis to Existing Stack

```hcl
# Just add this to terraform.tfvars
deploy_redis = true
```

Then run:
```bash
terraform plan
terraform apply
```

### Temporary Disable Module

To temporarily disable a module without destroying it:

```bash
# This will show a plan to destroy the module
deploy_rds = false

# To keep it, just don't apply
# To remove it, apply the change
terraform apply
```

## Troubleshooting

### Error: Module count is 0

This means the module is disabled. Check your deployment variables:

```hcl
# Check if you have:
deploy_eks = true  # Or whatever module you're trying to use
```

### Error: No declaration for variable

Make sure all required variables are set:

- For MongoDB Atlas: Set `mongodb_atlas_org_id`
- For Lambda: Set `lambda_filename` and `lambda_source_code_hash`

### Error: Resource not found

If referencing a conditionally deployed resource, use `try()`:

```hcl
# Good
value = try(module.eks[0].cluster_endpoint, null)

# Bad (will fail if EKS not deployed)
value = module.eks.cluster_endpoint
```

## Cost Optimization

Deploy only what you need to minimize costs:

| Stack Type | Monthly Cost (Estimate) | Recommended For |
|------------|-------------------------|-----------------|
| VPC + EKS only | ~$75-100 | Kubernetes development |
| VPC + ECS + RDS + ALB | ~$150-200 | Traditional web apps |
| VPC + Lambda + API GW | ~$10-50 | Serverless/low traffic |
| Full Stack | ~$300-500+ | Production workloads |

## Next Steps

1. Review `environments/dev/terraform.tfvars.example`
2. Create your own `terraform.tfvars` with desired modules
3. Run `terraform plan` to preview changes
4. Run `terraform apply` to deploy

For module-specific documentation, see:
- `EKS_USAGE_GUIDE.md`
- `MONGODB_ATLAS_USAGE_GUIDE.md`
- `REDIS_USAGE_GUIDE.md`
- `DEPLOYMENT_GUIDE.md`
