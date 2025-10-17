/**
 * Development Environment Variables
 */

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "DevTeam"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for database"
  type        = string
  default     = "dbadmin"
}

variable "container_image" {
  description = "Docker image for ECS container"
  type        = string
  default     = "nginx:latest"
}

variable "lambda_filename" {
  description = "Path to Lambda deployment package"
  type        = string
  default     = null
}

variable "lambda_source_code_hash" {
  description = "Base64-encoded SHA256 hash of Lambda package"
  type        = string
  default     = null
}

variable "mongodb_password" {
  description = "MongoDB Password"
  type        = string
  default     = null
}

variable "mongodb_atlas_org_id" {
  description = "MongoDB Atlas Organization ID"
  type        = string
  default     = ""
}

# Module Deployment Control
variable "deploy_rds" {
  description = "Deploy RDS Aurora module"
  type        = bool
  default     = false
}

variable "deploy_alb" {
  description = "Deploy Application Load Balancer module"
  type        = bool
  default     = false
}

variable "deploy_ecs_cluster" {
  description = "Deploy ECS Cluster module"
  type        = bool
  default     = false
}

variable "deploy_ecs_services" {
  description = "Deploy ECS Services"
  type        = bool
  default     = false
}

variable "deploy_eks" {
  description = "Deploy EKS Cluster module"
  type        = bool
  default     = true
}

variable "deploy_cloudfront_s3" {
  description = "Deploy CloudFront + S3 module"
  type        = bool
  default     = false
}

variable "deploy_lambda" {
  description = "Deploy Lambda function module"
  type        = bool
  default     = false
}

variable "deploy_api_gateway" {
  description = "Deploy API Gateway module"
  type        = bool
  default     = false
}

variable "deploy_redis" {
  description = "Deploy ElastiCache Redis module"
  type        = bool
  default     = false
}

variable "deploy_mongodb_atlas" {
  description = "Deploy MongoDB Atlas module"
  type        = bool
  default     = false
}
