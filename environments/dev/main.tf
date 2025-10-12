/**
 * Development Environment
 * 
 * This configuration deploys a complete AWS infrastructure stack for development
 * including VPC, ECS, RDS, ALB, CloudFront, API Gateway, and Lambda
 */

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  enable_nat_gateway = true
  single_nat_gateway = true # Cost optimization for dev

  enable_flow_logs        = false # Disabled for dev to save costs
  flow_logs_retention_days = 7

  common_tags = local.common_tags
}

# Security Groups Module
module "security_groups" {
  source = "../../modules/security-groups"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = module.vpc.vpc_cidr_block

  alb_ingress_cidr_blocks = ["0.0.0.0/0"]
  ecs_task_port           = 80  # Nginx default port
  rds_port                = 5432

  common_tags = local.common_tags
}

# RDS Aurora Module
module "rds_aurora" {
  source = "../../modules/rds-aurora"

  project_name       = var.project_name
  environment        = var.environment
  subnet_ids         = module.vpc.private_db_subnet_ids
  security_group_id  = module.security_groups.rds_security_group_id
  availability_zones = var.availability_zones

  engine              = "aurora-postgresql"
  engine_version      = "15.4"
  instance_class      = "db.t3.medium"
  replica_count       = 0 # No replicas in dev

  database_name   = var.db_name
  master_username = var.db_username

  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true

  performance_insights_enabled = false
  monitoring_interval          = 0

  common_tags = local.common_tags
}

# Application Load Balancer Module
module "alb" {
  source = "../../modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id

  internal                   = false
  enable_deletion_protection = false
  enable_access_logs         = false

  target_group_port     = 80  # Nginx default port
  health_check_path     = "/"  # Nginx default path
  health_check_interval = 30

  common_tags = local.common_tags
}

# ECS Cluster Module
module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  project_name = var.project_name
  environment  = var.environment

  enable_container_insights = true
  default_capacity_provider = "FARGATE"

  common_tags = local.common_tags
}

# ECS Service Module - Backend API
module "ecs_backend_service" {
  source = "../../modules/ecs-service"

  project_name  = var.project_name
  environment   = var.environment
  service_name  = "backend-api"
  aws_region    = var.aws_region

  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name

  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id

  task_cpu    = "512"
  task_memory = "1024"

  container_name  = "backend"
  container_image = "nginx:latest"  # Dummy nginx image
  container_port  = 80

  environment_variables = [
    {
      name  = "ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "DB_HOST"
      value = module.rds_aurora.cluster_endpoint
    }
  ]

  secrets = [
    {
      name      = "DB_PASSWORD"
      valueFrom = module.rds_aurora.secret_arn
    }
  ]

  desired_count            = 2
  enable_autoscaling       = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 5

  # ALB Integration
  target_group_arn = module.alb.target_group_arn

  # Use Fargate (not Spot) for dev
  use_fargate_spot = false

  common_tags = local.common_tags
}

# CloudFront + S3 Module for Frontend
# module "cloudfront_s3" {
#   source = "../../modules/cloudfront-s3"

#   project_name = var.project_name
#   environment  = var.environment

#   enable_versioning    = true
#   enable_logging       = false
#   price_class          = "PriceClass_100"

#   default_root_object = "index.html"

#   # SPA routing support
#   custom_error_responses = [
#     {
#       error_code            = 404
#       response_code         = 200
#       response_page_path    = "/index.html"
#       error_caching_min_ttl = 300
#     },
#     {
#       error_code            = 403
#       response_code         = 200
#       response_page_path    = "/index.html"
#       error_caching_min_ttl = 300
#     }
#   ]

#   common_tags = local.common_tags
# }

# Lambda Function Module (Example API function)
# module "lambda_api" {
#   source = "../../modules/lambda"

#   project_name  = var.project_name
#   environment   = var.environment
#   function_name = "api-handler"
#   description   = "API handler for serverless endpoints"

#   handler = "index.handler"
#   runtime = "python3.11"
#   timeout = 30
#   memory_size = 256

#   # Using dummy values - replace with actual deployment package
#   filename         = var.lambda_filename
#   source_code_hash = var.lambda_source_code_hash

#   vpc_config = {
#     subnet_ids         = module.vpc.private_app_subnet_ids
#     security_group_ids = [module.security_groups.lambda_security_group_id]
#   }

#   environment_variables = {
#     ENVIRONMENT = var.environment
#     DB_HOST     = module.rds_aurora.cluster_endpoint
#   }

#   allow_api_gateway = true

#   enable_xray_tracing = false
#   log_retention_days  = 7

#   common_tags = local.common_tags
# }

# API Gateway Module
# module "api_gateway" {
#   source = "../../modules/api-gateway"

#   project_name = var.project_name
#   environment  = var.environment
#   description  = "API Gateway for ${var.project_name} ${var.environment}"

#   stage_name                  = "v1"
#   create_proxy_resource       = true
#   lambda_function_invoke_arn  = module.lambda_api.function_invoke_arn

#   enable_xray_tracing = false
#   logging_level       = "INFO"
#   enable_metrics      = true

#   throttling_burst_limit = 1000
#   throttling_rate_limit  = 500

#   common_tags = local.common_tags
# }
