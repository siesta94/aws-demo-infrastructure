# module "ecs_backend_service" {
#   source = "../../modules/ecs-service"

#   project_name  = var.project_name
#   environment   = var.environment
#   service_name  = "backend-api"
#   aws_region    = var.aws_region

#   cluster_id   = module.ecs_cluster.cluster_id
#   cluster_name = module.ecs_cluster.cluster_name

#   subnet_ids        = module.vpc.private_app_subnet_ids
#   security_group_id = module.security_groups.ecs_tasks_security_group_id

#   task_cpu    = "512"
#   task_memory = "1024"

#   container_name  = "backend"
#   container_image = "nginx:latest"  # Dummy nginx image
#   container_port  = 80

#   environment_variables = [
#     {
#       name  = "ENVIRONMENT"
#       value = var.environment
#     },
#     {
#       name  = "DB_HOST"
#       value = module.rds_aurora.cluster_endpoint
#     }
#   ]

#   secrets = [
#     {
#       name      = "DB_PASSWORD"
#       valueFrom = module.rds_aurora.secret_arn
#     }
#   ]

#   desired_count            = 2
#   enable_autoscaling       = true
#   autoscaling_min_capacity = 1
#   autoscaling_max_capacity = 5

#   # ALB Integration
#   target_group_arn = module.alb.target_group_arn

#   # Use Fargate (not Spot) for dev
#   use_fargate_spot = false

#   common_tags = local.common_tags
# }