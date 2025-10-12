/**
 * Development Environment Outputs
 */

# VPC Outputs
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

# RDS Outputs
output "rds_cluster_endpoint" {
  description = "RDS Aurora cluster endpoint"
  value       = module.rds_aurora.cluster_endpoint
}

output "rds_cluster_reader_endpoint" {
  description = "RDS Aurora cluster reader endpoint"
  value       = module.rds_aurora.cluster_reader_endpoint
}

output "rds_secret_arn" {
  description = "ARN of the RDS credentials secret"
  value       = module.rds_aurora.secret_arn
}

# ALB Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the ALB"
  value       = module.alb.alb_zone_id
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_fargate.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_fargate.service_name
}

# CloudFront Outputs
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cloudfront_s3.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.cloudfront_s3.cloudfront_domain_name
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket for frontend"
  value       = module.cloudfront_s3.s3_bucket_id
}

# API Gateway Outputs
output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = module.api_gateway.stage_invoke_url
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = module.api_gateway.api_id
}

# Lambda Outputs
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda_api.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda_api.function_arn
}
