# AWS Multi-Environment Terraform Infrastructure

This Terraform project provides a complete, production-ready AWS infrastructure with support for multiple environments (dev, staging, production).

## Architecture Overview

This infrastructure includes:

- **VPC**: Multi-AZ VPC with public/private subnets, NAT gateways, and route tables
- **ECS Cluster**: Fargate-based container orchestration with auto-scaling
- **EKS Cluster**: Managed Kubernetes service with node groups and IRSA support
- **Application Load Balancers**: For distributing traffic to ECS services
- **CloudFront + S3**: CDN distribution for frontend static assets
- **API Gateway**: RESTful API endpoints for serverless functions
- **Lambda Functions**: Event-driven serverless compute
- **RDS Aurora**: PostgreSQL-compatible cluster with read replicas
- **ElastiCache Redis**: In-memory data store for caching and real-time use cases
- **Security Groups**: Fine-grained network access control

## Project Structure

```
.
├── environments/          # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── production/
├── modules/              # Reusable Terraform modules
│   ├── vpc/
│   ├── security-groups/
│   ├── rds-aurora/
│   ├── ecs-cluster/
│   ├── ecs-service/
│   ├── ecs-fargate/
│   ├── eks/
│   ├── alb/
│   ├── cloudfront-s3/
│   ├── api-gateway/
│   ├── lambda/
│   └── elasticache-redis/
├── scripts/              # Helper scripts
└── README.md
```

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- S3 bucket for Terraform state (recommended)

## Usage

### Initialize Environment

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### Deploy to Different Environments

```bash
# Development
cd environments/dev
terraform apply

# Staging
cd environments/staging
terraform apply

# Production
cd environments/production
terraform apply
```

## Environment Variables

Each environment supports customization through `terraform.tfvars`:

- `environment`: Environment name (dev/staging/production)
- `aws_region`: AWS region for deployment
- `vpc_cidr`: VPC CIDR block
- `availability_zones`: List of AZs to use
- `enable_nat_gateway`: Enable NAT gateway for private subnets
- `ecs_cluster_name`: Name of the ECS cluster
- `rds_instance_class`: RDS instance type
- `enable_read_replica`: Enable RDS read replicas

## Security Considerations

- All RDS databases are in private subnets
- Security groups follow least-privilege principle
- CloudFront uses OAI for S3 access
- Secrets are managed via AWS Secrets Manager
- Enable encryption at rest for all data stores

## Cost Optimization

- Use appropriate instance sizes per environment
- Disable NAT gateways in dev if not needed
- Use Aurora Serverless for non-production environments
- Implement auto-scaling policies
- Use S3 lifecycle policies

## Maintenance

- Regular Terraform state backups
- Periodic security group audits
- Database backup verification
- Monitoring and alerting setup

## Contributing

1. Create feature branch
2. Make changes
3. Test in dev environment
4. Submit pull request

## License

MIT License
