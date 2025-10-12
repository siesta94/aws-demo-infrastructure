# AWS Infrastructure Deployment Guide

This guide provides step-by-step instructions for deploying the complete AWS infrastructure across different environments.

## Architecture Overview

This Terraform project deploys a complete, production-ready AWS infrastructure including:

### Core Services
- **VPC**: Multi-AZ networking with public/private subnets
- **ECS Fargate**: Containerized application hosting
- **RDS Aurora**: PostgreSQL-compatible database cluster
- **Application Load Balancer**: Traffic distribution and SSL termination
- **CloudFront + S3**: Global CDN for frontend assets
- **API Gateway**: RESTful API management
- **Lambda**: Serverless compute functions

### Security Features
- Private subnets for application and database layers
- Security groups with least-privilege access
- Secrets Manager for credential management
- Encryption at rest for all data stores
- VPC Flow Logs (optional)

## Quick Start

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.5.0 installed
3. **AWS CLI** configured with credentials
4. **Docker image** for your application (stored in ECR or Docker Hub)

### Initial Setup

```bash
# Clone the repository
cd aws-demo-infrastructure

# Choose your environment
cd environments/dev

# Initialize Terraform
terraform init

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### Deploy Infrastructure

```bash
# Review planned changes
terraform plan

# Apply configuration
terraform apply

# Note the outputs (ALB URL, CloudFront domain, etc.)
terraform output
```

## Environment-Specific Deployment

### Development Environment

```bash
cd environments/dev
terraform init
terraform apply
```

**Features:**
- Single NAT Gateway (cost optimized)
- No RDS read replicas
- Smaller instance sizes
- Minimal logging/monitoring
- No deletion protection

### Staging Environment

```bash
cd environments/staging
terraform init
terraform apply
```

**Features:**
- Production-like configuration
- Single read replica
- Enhanced monitoring
- Moderate instance sizes

### Production Environment

```bash
cd environments/production
terraform init
terraform apply
```

**Features:**
- High availability across AZs
- Multiple read replicas
- Full monitoring and alerting
- Deletion protection enabled
- Performance insights
- Enhanced backup retention

## Post-Deployment Steps

### 1. Deploy Application to ECS

```bash
# Build and push Docker image
docker build -t myapp:latest .
docker tag myapp:latest <account-id>.dkr.ecr.<region>.amazonaws.com/myapp:latest
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/myapp:latest

# Update ECS service with new image
aws ecs update-service \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --service $(terraform output -raw ecs_service_name) \
  --force-new-deployment
```

### 2. Deploy Frontend to S3/CloudFront

```bash
# Build frontend
npm run build

# Sync to S3
aws s3 sync ./build s3://$(terraform output -raw s3_bucket_id)

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

### 3. Configure Database

```bash
# Get database credentials
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw rds_secret_arn) \
  --query SecretString --output text | jq

# Run migrations (example with psql)
export DB_HOST=$(terraform output -raw rds_cluster_endpoint)
export DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id $(terraform output -raw rds_secret_arn) --query SecretString --output text | jq -r .password)
psql -h $DB_HOST -U dbadmin -d appdb -f migrations.sql
```

### 4. Deploy Lambda Functions

```bash
# Package Lambda function
cd lambda
zip -r function.zip .

# Update Terraform with Lambda package
terraform apply -var="lambda_filename=lambda/function.zip"
```

## Remote State Management

For team collaboration, configure remote state:

```hcl
# In main.tf, uncomment and configure:
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

Create required resources:

```bash
# Create S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Monitoring and Logging

### CloudWatch Dashboards

```bash
# Access CloudWatch console
aws cloudwatch get-dashboard --dashboard-name myapp-dev
```

### View Logs

```bash
# ECS logs
aws logs tail /ecs/myapp-dev --follow

# Lambda logs
aws logs tail /aws/lambda/myapp-dev-api-handler --follow

# API Gateway logs
aws logs tail /aws/apigateway/myapp-dev --follow
```

### Set Up Alarms

CloudWatch alarms are automatically created for:
- ECS CPU/Memory utilization
- RDS connections and CPU
- ALB target health
- Lambda errors and throttles
- API Gateway 4xx/5xx errors

## Scaling

### Manual Scaling

```bash
# Scale ECS service
aws ecs update-service \
  --cluster myapp-dev-cluster \
  --service myapp-dev-service \
  --desired-count 5
```

### Auto-Scaling

Auto-scaling is configured by default:
- **ECS**: Based on CPU (70%) and Memory (80%)
- **RDS**: Manual scaling (can add read replicas)
- **API Gateway**: Automatic by AWS

## Disaster Recovery

### Backup Strategy

- **RDS**: Automated backups (7-30 days retention)
- **S3**: Versioning enabled
- **ECS**: Stateless, can redeploy from images

### Restore Procedure

```bash
# Restore RDS from snapshot
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier myapp-restored \
  --snapshot-identifier myapp-snapshot-id

# Restore S3 objects
aws s3api list-object-versions --bucket myapp-frontend
aws s3api get-object --bucket myapp-frontend --key file.js --version-id <version>
```

## Cost Optimization

### Development Environment
- Use single NAT Gateway: ~$32/month savings
- Disable Performance Insights: ~$7/month savings
- Use Fargate Spot: Up to 70% savings
- Smaller instance sizes

### Production Environment
- Use Reserved Instances for predictable workloads
- Enable S3 Intelligent-Tiering
- Configure ALB idle timeout
- Use CloudFront caching effectively

## Troubleshooting

### Common Issues

1. **Terraform State Lock**
   ```bash
   # Force unlock if needed (use carefully)
   terraform force-unlock <lock-id>
   ```

2. **ECS Task Won't Start**
   - Check CloudWatch logs
   - Verify image exists and is accessible
   - Check security group rules
   - Verify IAM role permissions

3. **Database Connection Failures**
   - Verify security group allows traffic from ECS
   - Check RDS cluster status
   - Verify credentials in Secrets Manager

4. **CloudFront Not Serving Updates**
   - Create invalidation
   - Check S3 bucket permissions
   - Verify OAI configuration

## Security Best Practices

1. **Secrets Management**
   - Never commit terraform.tfvars
   - Use Secrets Manager for credentials
   - Rotate credentials regularly

2. **Network Security**
   - Use private subnets for app/database
   - Restrict security group rules
   - Enable VPC Flow Logs in production

3. **Access Control**
   - Use IAM roles, not access keys
   - Follow principle of least privilege
   - Enable MFA for AWS console access

4. **Compliance**
   - Enable encryption at rest
   - Configure audit logging
   - Regular security assessments

## Updating Infrastructure

```bash
# Update a module
cd environments/dev
terraform plan
terraform apply

# Update only specific resource
terraform apply -target=module.ecs_fargate
```

## Destroying Infrastructure

```bash
# Destroy development environment
cd environments/dev
terraform destroy

# Destroy specific module
terraform destroy -target=module.ecs_fargate
```

**Warning**: Production environments have deletion protection enabled.

## Support

For issues or questions:
1. Check module documentation in `modules/*/README.md`
2. Review CloudWatch logs
3. Check AWS service health dashboard
4. Consult Terraform documentation

## Next Steps

1. Configure custom domain names
2. Set up CI/CD pipeline
3. Implement blue-green deployments
4. Add WAF rules
5. Configure backup automation
6. Set up cross-region replication (DR)
