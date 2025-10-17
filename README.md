# AWS Multi-Environment Terraform Infrastructure

This Terraform project provides a complete, production-ready AWS infrastructure with support for multiple environments (dev, staging, production) and **flexible module deployment**.

## 🎯 Key Feature: Flexible Module Deployment

**Deploy only what you need!** All infrastructure modules are now independently toggleable via boolean variables. No more commenting out code or dealing with module dependencies.

- ✅ Deploy just EKS for Kubernetes workloads
- ✅ Deploy ECS stack for containerized apps
- ✅ Deploy serverless Lambda + API Gateway
- ✅ Mix and match modules as needed
- ✅ No hard dependencies between modules (except VPC/SG)

See [FLEXIBLE_DEPLOYMENT_GUIDE.md](FLEXIBLE_DEPLOYMENT_GUIDE.md) for complete documentation.

## Architecture Overview

This infrastructure includes:

### Core Infrastructure (Always Required)
- **VPC**: Multi-AZ VPC with public/private subnets, NAT gateways, and route tables
- **Security Groups**: Fine-grained network access control

### Optional Modules (Deploy as Needed)
- **EKS Cluster**: Managed Kubernetes service with node groups and IRSA support (✅ Default: Enabled)
- **ECS Cluster**: Fargate-based container orchestration with auto-scaling
- **Application Load Balancers**: For distributing traffic to ECS services
- **RDS Aurora**: PostgreSQL-compatible cluster with read replicas
- **Lambda Functions**: Event-driven serverless compute
- **API Gateway**: RESTful API endpoints for serverless functions
- **ElastiCache Redis**: In-memory data store for caching and real-time use cases
- **CloudFront + S3**: CDN distribution for frontend static assets
- **MongoDB Atlas**: Managed MongoDB clusters with VPC peering and PrivateLink integration

## Project Structure

```
.
├── environments/          # Environment-specific configurations
│   └── dev/
│       ├── main.tf              # Main configuration with all modules
│       ├── variables.tf         # Variables including deploy_* toggles
│       ├── outputs.tf           # Conditional outputs
│       └── terraform.tfvars.example
├── modules/              # Reusable Terraform modules
│   ├── vpc/
│   ├── security-groups/
│   ├── eks/              # ⭐ NEW: Kubernetes cluster
│   ├── ecs-cluster/
│   ├── ecs-service/
│   ├── ecs-fargate/
│   ├── rds-aurora/
│   ├── alb/
│   ├── lambda/
│   ├── api-gateway/
│   ├── elasticache-redis/
│   ├── cloudfront-s3/
│   └── mongodb-atlas/    # ⭐ NEW: MongoDB Atlas integration
├── FLEXIBLE_DEPLOYMENT_GUIDE.md  # ⭐ Complete deployment guide
├── EKS_USAGE_GUIDE.md            # ⭐ EKS module documentation
├── MONGODB_ATLAS_USAGE_GUIDE.md  # ⭐ MongoDB Atlas guide
└── README.md
```

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- S3 bucket for Terraform state (recommended)
- MongoDB Atlas account (if using MongoDB module)

## Quick Start

### 1. Configure Your Deployment

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to enable the modules you need:

```hcl
# Example: Deploy just EKS (default)
deploy_eks = true

# Example: Deploy ECS stack instead
deploy_eks          = false
deploy_ecs_cluster  = true
deploy_ecs_services = true
deploy_alb          = true
deploy_rds          = true
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

## Deployment Examples

### Example 1: EKS Only (Default - Lowest Cost)

```hcl
# terraform.tfvars
deploy_eks = true
# All other modules default to false
```

**What this deploys:**
- VPC with public/private subnets
- Security Groups
- EKS Cluster with managed node groups
- All essential EKS add-ons (VPC CNI, kube-proxy, CoreDNS, EBS CSI)

**Estimated monthly cost:** ~$75-100

### Example 2: ECS Web Application

```hcl
# terraform.tfvars
deploy_eks          = false
deploy_ecs_cluster  = true
deploy_ecs_services = true
deploy_alb          = true
deploy_rds          = true
deploy_redis        = true
```

**What this deploys:**
- VPC + Security Groups
- ECS Fargate cluster
- Application Load Balancer
- RDS Aurora PostgreSQL
- ElastiCache Redis
- Auto-scaling ECS services

**Estimated monthly cost:** ~$150-200

### Example 3: Serverless Stack

```hcl
# terraform.tfvars
deploy_eks           = false
deploy_lambda        = true
deploy_api_gateway   = true
deploy_mongodb_atlas = true
mongodb_atlas_org_id = "your-org-id"
mongodb_password     = "secure-password"
```

**What this deploys:**
- VPC + Security Groups
- Lambda functions
- API Gateway
- MongoDB Atlas cluster

**Estimated monthly cost:** ~$10-50

## Module Deployment Control

All modules can be toggled using these variables in `terraform.tfvars`:

| Variable | Description | Default | Dependencies |
|----------|-------------|---------|--------------|
| `deploy_eks` | Deploy EKS Cluster | `true` | None |
| `deploy_ecs_cluster` | Deploy ECS Cluster | `false` | None |
| `deploy_ecs_services` | Deploy ECS Services | `false` | ECS Cluster + ALB |
| `deploy_rds` | Deploy RDS Aurora | `false` | None |
| `deploy_alb` | Deploy ALB | `false` | None |
| `deploy_lambda` | Deploy Lambda | `false` | None |
| `deploy_api_gateway` | Deploy API Gateway | `false` | Lambda |
| `deploy_redis` | Deploy Redis | `false` | None |
| `deploy_cloudfront_s3` | Deploy CloudFront+S3 | `false` | None |
| `deploy_mongodb_atlas` | Deploy MongoDB Atlas | `false` | None |

## Documentation

### Module-Specific Guides
- [Flexible Deployment Guide](FLEXIBLE_DEPLOYMENT_GUIDE.md) - **Start here!** Complete guide to selective module deployment
- [EKS Usage Guide](EKS_USAGE_GUIDE.md) - Comprehensive EKS module documentation
- [MongoDB Atlas Guide](MONGODB_ATLAS_USAGE_GUIDE.md) - MongoDB Atlas integration guide
- [Redis Usage Guide](REDIS_USAGE_GUIDE.md) - ElastiCache Redis configuration
- [Deployment Guide](DEPLOYMENT_GUIDE.md) - General deployment instructions
- [Multiple Services Guide](MULTIPLE_SERVICES_GUIDE.md) - Running multiple ECS services
- [Security Groups Explained](SECURITY_GROUPS_EXPLAINED.md) - Network security documentation
- [Custom Security Rules](CUSTOM_SECURITY_RULES.md) - Creating custom security rules

## Key Features

### 🔧 Flexibility
- **Independent modules** - Deploy any combination without dependencies
- **Cost optimization** - Pay only for what you deploy
- **Easy testing** - Test individual modules in isolation

### 🔒 Security
- All databases in private subnets
- Least-privilege security groups
- Secrets managed via AWS Secrets Manager
- Encryption at rest for all data stores
- VPC peering and PrivateLink support

### 📊 Scalability
- Auto-scaling for ECS services and EKS nodes
- Multi-AZ deployment for high availability
- CloudFront CDN for global content delivery
- Redis caching for improved performance

### 💰 Cost Optimization
- Deploy only needed modules
- Fargate Spot for cost savings
- Aurora Serverless support
- S3 lifecycle policies
- Right-sized instances per environment

## Environment Configuration

Each environment supports customization through `terraform.tfvars`:

**Basic Configuration:**
- `aws_region`: AWS region for deployment
- `project_name`: Name of your project
- `environment`: Environment name (dev/staging/production)
- `vpc_cidr`: VPC CIDR block
- `availability_zones`: List of AZs to use

**Module Control:**
- `deploy_*`: Boolean flags to enable/disable modules

**Module-Specific:**
- `db_name`, `db_username`: RDS configuration
- `container_image`: Docker image for ECS
- `mongodb_atlas_org_id`: MongoDB Atlas organization
- `lambda_filename`: Lambda deployment package

## Common Operations

### Switch from ECS to EKS

```hcl
# In terraform.tfvars
deploy_ecs_cluster  = false
deploy_ecs_services = false
deploy_alb          = false
deploy_eks          = true
```

```bash
terraform apply
```

### Add Redis to Existing Deployment

```hcl
# In terraform.tfvars
deploy_redis = true
```

```bash
terraform apply
```

### Deploy Only Base Infrastructure

```hcl
# In terraform.tfvars
deploy_eks = false
# All other deploy_* default to false
```

This deploys only VPC and Security Groups - useful for testing or as a foundation for custom resources.

## Security Considerations

- ✅ All databases in private subnets
- ✅ Security groups follow least-privilege principle
- ✅ CloudFront uses OAI for S3 access
- ✅ Secrets managed via AWS Secrets Manager
- ✅ Encryption at rest enabled
- ✅ VPC Flow Logs support
- ✅ IRSA for EKS pod-level IAM permissions

## Maintenance

- Regular Terraform state backups
- Periodic security group audits
- Database backup verification
- Monitoring and alerting setup (CloudWatch)
- Regular updates to module versions

## Troubleshooting

### Module Not Found Error

```
Error: No module call named "ecs_cluster"
```

**Solution:** The module is disabled. Set the corresponding `deploy_*` variable to `true` in `terraform.tfvars`.

### Output is Null

All outputs return `null` if the corresponding module isn't deployed. This is expected behavior.

### Dependency Error

**ECS Services won't deploy?** Check that both `deploy_ecs_cluster` and `deploy_alb` are set to `true`.

**API Gateway won't deploy?** Check that `deploy_lambda` is set to `true`.

See [FLEXIBLE_DEPLOYMENT_GUIDE.md](FLEXIBLE_DEPLOYMENT_GUIDE.md) for more troubleshooting tips.

## Contributing

1. Create feature branch
2. Make changes to modules
3. Test in dev environment
4. Update documentation
5. Submit pull request

## License

MIT License

## Changelog

### v2.0 - Flexible Deployment
- ✨ Added EKS module with full Kubernetes support
- ✨ Added MongoDB Atlas module with VPC peering
- ✨ Implemented flexible module deployment system
- ✨ All modules now independently toggleable
- ✨ Conditional outputs for all modules
- 📚 Comprehensive documentation updates

### v1.0 - Initial Release
- Initial infrastructure modules
- ECS, RDS, Lambda, CloudFront support
