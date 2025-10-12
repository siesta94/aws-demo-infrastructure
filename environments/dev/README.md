# Development Environment

This directory contains the Terraform configuration for the development environment.

## Infrastructure Components

- **VPC**: 10.0.0.0/16 with 2 availability zones
- **ECS Fargate**: Container orchestration with auto-scaling (1-5 tasks)
- **RDS Aurora**: PostgreSQL cluster (no read replicas in dev)
- **Application Load Balancer**: HTTP/HTTPS traffic distribution
- **CloudFront + S3**: Frontend static asset distribution
- **API Gateway**: RESTful API endpoints
- **Lambda**: Serverless function execution

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- Docker image for ECS (update `container_image` variable)

## Deployment

### 1. Initialize Terraform

```bash
cd environments/dev
terraform init
```

### 2. Configure Variables

Copy the example tfvars file and customize:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Plan Deployment

```bash
terraform plan
```

### 4. Apply Configuration

```bash
terraform apply
```

## Configuration

### Key Variables

- `aws_region`: AWS region (default: us-east-1)
- `project_name`: Name of your project
- `vpc_cidr`: VPC CIDR block
- `container_image`: Docker image for ECS
- `db_name`: Database name
- `db_username`: Database admin username

### Cost Optimization Features

- Single NAT Gateway (instead of per-AZ)
- No RDS read replicas
- VPC Flow Logs disabled
- Smaller instance sizes
- No Performance Insights on RDS

## Outputs

After deployment, you'll receive:

- ALB DNS name for accessing your application
- CloudFront domain for frontend
- API Gateway URL for API endpoints
- RDS cluster endpoint
- S3 bucket name for frontend assets

## Accessing Resources

### Application

```bash
# Get ALB DNS name
terraform output alb_dns_name
```

### Frontend

```bash
# Get CloudFront domain
terraform output cloudfront_domain_name

# Upload files to S3
aws s3 sync ./frontend s3://$(terraform output -raw s3_bucket_id)

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

### Database

```bash
# Get database credentials from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw rds_secret_arn) \
  --query SecretString \
  --output text
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources including databases. Ensure you have backups if needed.

## Troubleshooting

### Common Issues

1. **Lambda deployment package not found**
   - Ensure `lambda_filename` points to a valid .zip file
   - Or comment out the Lambda module if not needed

2. **Container image pull errors**
   - Verify the `container_image` variable points to a valid image
   - Ensure ECR permissions if using private registry

3. **Database connection issues**
   - Check security group rules
   - Verify ECS tasks are in correct subnets
   - Check RDS cluster status

## Next Steps

1. Configure CI/CD pipeline
2. Set up monitoring and alerting
3. Configure custom domain names
4. Implement backup strategy
5. Add WAF rules for CloudFront/ALB
