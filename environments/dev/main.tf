/**
 * Development Environment
 * 
 * This configuration deploys a flexible AWS infrastructure stack
 * Use variables to control which modules are deployed
 */

# VPC Module (Always required)
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  enable_nat_gateway = true
  single_nat_gateway = true # Cost optimization for dev

  enable_flow_logs         = false # Disabled for dev to save costs
  flow_logs_retention_days = 7

  common_tags = local.common_tags
}

# Security Groups Module (Always required)
module "security_groups" {
  source = "../../modules/security-groups"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = module.vpc.vpc_cidr_block

  alb_ingress_cidr_blocks = ["0.0.0.0/0"]
  ecs_task_port           = 80
  rds_port                = 5432

  common_tags = local.common_tags
}

# RDS Aurora Module (Optional)
module "rds_aurora" {
  count  = var.deploy_rds ? 1 : 0
  source = "../../modules/rds-aurora"

  project_name       = var.project_name
  environment        = var.environment
  subnet_ids         = module.vpc.private_db_subnet_ids
  security_group_id  = module.security_groups.rds_security_group_id
  availability_zones = var.availability_zones

  engine         = "aurora-postgresql"
  engine_version = "15.4"
  instance_class = "db.t3.medium"
  replica_count  = 0 # No replicas in dev

  database_name   = var.db_name
  master_username = var.db_username

  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true

  performance_insights_enabled = false
  monitoring_interval          = 0

  common_tags = local.common_tags
}

# Application Load Balancer Module (Optional)
module "alb" {
  count  = var.deploy_alb ? 1 : 0
  source = "../../modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id

  internal                   = false
  enable_deletion_protection = false
  enable_access_logs         = false

  target_group_port     = 80
  health_check_path     = "/"
  health_check_interval = 30

  common_tags = local.common_tags
}

# ECS Cluster Module (Optional)
module "ecs_cluster" {
  count  = var.deploy_ecs_cluster ? 1 : 0
  source = "../../modules/ecs-cluster"

  project_name = var.project_name
  environment  = var.environment

  enable_container_insights = true
  default_capacity_provider = "FARGATE"

  common_tags = local.common_tags
}

# ECS Service Module (Optional - requires ECS cluster and ALB)
module "ecs_backend_service" {
  count  = var.deploy_ecs_services && var.deploy_ecs_cluster && var.deploy_alb ? 1 : 0
  source = "../../modules/ecs-service"

  project_name = var.project_name
  environment  = var.environment
  service_name = "backend-api"
  aws_region   = var.aws_region

  cluster_id   = module.ecs_cluster[0].cluster_id
  cluster_name = module.ecs_cluster[0].cluster_name

  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id

  task_cpu    = "512"
  task_memory = "1024"

  container_name  = "backend"
  container_image = var.container_image
  container_port  = 80

  environment_variables = concat(
    [
      {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    ],
    var.deploy_rds ? [
      {
        name  = "DB_HOST"
        value = module.rds_aurora[0].cluster_endpoint
      }
    ] : []
  )

  secrets = var.deploy_rds ? [
    {
      name      = "DB_PASSWORD"
      valueFrom = module.rds_aurora[0].secret_arn
    }
  ] : []

  desired_count            = 2
  enable_autoscaling       = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 5

  # ALB Integration
  target_group_arn = module.alb[0].target_group_arn

  use_fargate_spot = false

  common_tags = local.common_tags
}

# EKS Module (Optional)
module "eks" {
  count  = var.deploy_eks ? 1 : 0
  source = "../../modules/eks"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_app_subnet_ids
  node_group_subnet_ids = module.vpc.private_app_subnet_ids

  # Security configuration
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  # Enable essential add-ons
  enable_vpc_cni_addon        = true
  enable_kube_proxy_addon     = true
  enable_coredns_addon        = true
  enable_ebs_csi_driver_addon = true

  # Enable IRSA
  enable_irsa = true

  common_tags = local.common_tags
}

# CloudFront + S3 Module for Frontend (Optional)
module "cloudfront_s3" {
  count  = var.deploy_cloudfront_s3 ? 1 : 0
  source = "../../modules/cloudfront-s3"

  project_name = var.project_name
  environment  = var.environment

  enable_versioning = true
  enable_logging    = false
  price_class       = "PriceClass_100"

  default_root_object = "index.html"

  # SPA routing support
  custom_error_responses = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]

  common_tags = local.common_tags
}

# Lambda Function Module (Optional)
module "lambda_api" {
  count  = var.deploy_lambda ? 1 : 0
  source = "../../modules/lambda"

  project_name  = var.project_name
  environment   = var.environment
  function_name = "api-handler"
  description   = "API handler for serverless endpoints"

  handler     = "index.handler"
  runtime     = "python3.11"
  timeout     = 30
  memory_size = 256

  filename         = var.lambda_filename
  source_code_hash = var.lambda_source_code_hash

  vpc_config = {
    subnet_ids         = module.vpc.private_app_subnet_ids
    security_group_ids = [module.security_groups.lambda_security_group_id]
  }

  environment_variables = var.deploy_rds ? {
    ENVIRONMENT = var.environment
    DB_HOST     = module.rds_aurora[0].cluster_endpoint
  } : {
    ENVIRONMENT = var.environment
  }

  allow_api_gateway = true

  enable_xray_tracing = false
  log_retention_days  = 7

  common_tags = local.common_tags
}

# API Gateway Module (Optional - requires Lambda)
module "api_gateway" {
  count  = var.deploy_api_gateway && var.deploy_lambda ? 1 : 0
  source = "../../modules/api-gateway"

  project_name = var.project_name
  environment  = var.environment
  description  = "API Gateway for ${var.project_name} ${var.environment}"

  stage_name                 = "v1"
  create_proxy_resource      = true
  lambda_function_invoke_arn = module.lambda_api[0].function_invoke_arn

  enable_xray_tracing = false
  logging_level       = "INFO"
  enable_metrics      = true

  throttling_burst_limit = 1000
  throttling_rate_limit  = 500

  common_tags = local.common_tags
}

# ElastiCache Redis Module (Optional)
module "redis" {
  count  = var.deploy_redis ? 1 : 0
  source = "../../modules/elasticache-redis"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.vpc.private_db_subnet_ids
  security_group_id = module.security_groups.redis_security_group_id

  node_type          = "cache.t3.micro"
  num_cache_nodes    = 1
  engine_version     = "7.0"
  parameter_group_family = "redis7"

  automatic_failover_enabled = false
  multi_az_enabled           = false

  snapshot_retention_limit = 0
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:05:00-sun:07:00"

  common_tags = local.common_tags
}

# MongoDB Atlas Module (Optional)
module "mongodb_atlas" {
  count  = var.deploy_mongodb_atlas ? 1 : 0
  source = "../../modules/mongodb-atlas"

  project_name = var.project_name
  environment  = var.environment
  atlas_org_id = var.mongodb_atlas_org_id

  instance_size   = "M10"
  mongodb_version = "7.0"
  atlas_region    = "US_EAST_1"

  database_users = var.mongodb_password != null ? {
    app_user = {
      username           = "appuser"
      password           = var.mongodb_password
      auth_database_name = "admin"
      roles = [{
        role_name     = "readWrite"
        database_name = "${var.project_name}_${var.environment}"
      }]
      scopes = []
      labels = {}
    }
  } : {}

  ip_whitelist = {
    vpc = {
      cidr_block = module.vpc.vpc_cidr_block
      comment    = "VPC access"
    }
  }
}
