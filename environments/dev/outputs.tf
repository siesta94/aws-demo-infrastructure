/**
 * Development Environment Outputs
 * 
 * All outputs are conditional - they only export values if the corresponding module is deployed
 */

# VPC Outputs (always available as VPC is required)
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of private application subnets"
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of private database subnets"
  value       = module.vpc.private_db_subnet_ids
}

# Security Groups Outputs (always available as SG is required)
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security_groups.alb_security_group_id
}

output "ecs_tasks_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = module.security_groups.ecs_tasks_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.security_groups.rds_security_group_id
}

# RDS Outputs (conditional)
output "rds_cluster_endpoint" {
  description = "RDS Aurora cluster endpoint"
  value       = try(module.rds_aurora[0].cluster_endpoint, null)
}

output "rds_cluster_reader_endpoint" {
  description = "RDS Aurora cluster reader endpoint"
  value       = try(module.rds_aurora[0].cluster_reader_endpoint, null)
}

output "rds_secret_arn" {
  description = "ARN of the RDS credentials secret"
  value       = try(module.rds_aurora[0].secret_arn, null)
}

# ALB Outputs (conditional)
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = try(module.alb[0].alb_dns_name, null)
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = try(module.alb[0].alb_zone_id, null)
}

output "alb_target_group_arn" {
  description = "ARN of the ALB target group"
  value       = try(module.alb[0].target_group_arn, null)
}

# ECS Outputs (conditional)
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = try(module.ecs_cluster[0].cluster_name, null)
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = try(module.ecs_cluster[0].cluster_id, null)
}

output "ecs_backend_service_name" {
  description = "Name of the ECS backend service"
  value       = try(module.ecs_backend_service[0].service_name, null)
}

# EKS Outputs (conditional)
output "eks_cluster_id" {
  description = "ID of the EKS cluster"
  value       = try(module.eks[0].cluster_id, null)
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS Kubernetes API server"
  value       = try(module.eks[0].cluster_endpoint, null)
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = try(module.eks[0].cluster_name, null)
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = try(module.eks[0].cluster_security_group_id, null)
}

output "eks_node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = try(module.eks[0].node_security_group_id, null)
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC Provider for EKS"
  value       = try(module.eks[0].oidc_provider_arn, null)
}

# CloudFront Outputs (conditional)
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = try(module.cloudfront_s3[0].cloudfront_distribution_id, null)
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = try(module.cloudfront_s3[0].cloudfront_domain_name, null)
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket for frontend"
  value       = try(module.cloudfront_s3[0].s3_bucket_id, null)
}

# API Gateway Outputs (conditional)
output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = try(module.api_gateway[0].stage_invoke_url, null)
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = try(module.api_gateway[0].api_id, null)
}

# Lambda Outputs (conditional)
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = try(module.lambda_api[0].function_name, null)
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = try(module.lambda_api[0].function_arn, null)
}

# ElastiCache Redis Outputs (conditional)
output "redis_endpoint" {
  description = "Endpoint of the ElastiCache Redis cluster"
  value       = try(module.redis[0].redis_endpoint, null)
}

output "redis_port" {
  description = "Port of the ElastiCache Redis cluster"
  value       = try(module.redis[0].redis_port, null)
}

# MongoDB Atlas Outputs (conditional)
output "mongodb_connection_string" {
  description = "MongoDB Atlas connection string"
  value       = try(module.mongodb_atlas[0].connection_strings.standard_srv, null)
  sensitive   = true
}

output "mongodb_cluster_name" {
  description = "Name of the MongoDB Atlas cluster"
  value       = try(module.mongodb_atlas[0].cluster_name, null)
}
