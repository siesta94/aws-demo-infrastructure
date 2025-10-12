# Creating Multiple ECS Services

This guide explains how to deploy multiple ECS services (e.g., frontend, backend, worker) using the existing modular structure.

## Important: Cluster vs Services

The project now includes two separate modules for ECS:

1. **`ecs-cluster`**: Creates a single ECS cluster (use once per environment)
2. **`ecs-service`**: Creates individual services on a cluster (use multiple times)

**Old approach** (ecs-fargate module): Creates cluster + service together → Multiple clusters ❌
**New approach** (ecs-cluster + ecs-service): One cluster, multiple services → Correct ✅

## Recommended Approach: One Cluster, Multiple Services

The best approach is to create ONE cluster and deploy multiple services to it.

### Complete Example with New Modules

```hcl
# In environments/dev/main.tf

# Step 1: Create ONE ECS Cluster
module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  project_name              = var.project_name
  environment               = var.environment
  enable_container_insights = true

  common_tags = local.common_tags
}

# Step 2: Create Multiple Services on the Same Cluster

# Backend API Service
module "ecs_backend_api" {
  source = "../../modules/ecs-service"

  project_name  = var.project_name
  environment   = var.environment
  service_name  = "backend-api"
  aws_region    = var.aws_region
  
  # Reference the cluster we created above
  cluster_id    = module.ecs_cluster.cluster_id
  cluster_name  = module.ecs_cluster.cluster_name

  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  target_group_arn  = module.alb_backend.target_group_arn

  container_name  = "backend-api"
  container_image = "your-repo/backend-api:latest"
  container_port  = 8080

  task_cpu    = "512"
  task_memory = "1024"

  environment_variables = [
    {
      name  = "DB_HOST"
      value = module.rds_aurora.cluster_endpoint
    }
  ]

  desired_count            = 2
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 10

  common_tags = local.common_tags
}

# Worker Service (same cluster, no load balancer)
module "ecs_worker" {
  source = "../../modules/ecs-service"

  project_name  = var.project_name
  environment   = var.environment
  service_name  = "worker"
  aws_region    = var.aws_region
  
  # Same cluster as backend
  cluster_id    = module.ecs_cluster.cluster_id
  cluster_name  = module.ecs_cluster.cluster_name

  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  # No target_group_arn - worker doesn't need ALB

  container_name  = "worker"
  container_image = "your-repo/worker:latest"
  container_port  = 8080

  task_cpu    = "256"
  task_memory = "512"

  environment_variables = [
    {
      name  = "QUEUE_URL"
      value = "your-sqs-queue-url"
    }
  ]

  desired_count = 1

  common_tags = local.common_tags
}

# Admin Service (same cluster)
module "ecs_admin" {
  source = "../../modules/ecs-service"

  project_name  = var.project_name
  environment   = var.environment
  service_name  = "admin"
  aws_region    = var.aws_region
  
  cluster_id    = module.ecs_cluster.cluster_id
  cluster_name  = module.ecs_cluster.cluster_name

  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  target_group_arn  = module.alb_admin.target_group_arn

  container_name  = "admin"
  container_image = "your-repo/admin:latest"
  container_port  = 3000

  task_cpu    = "256"
  task_memory = "512"

  desired_count = 1

  common_tags = local.common_tags
}
```

**Result:** ✅ One cluster with three services running on it!

### Legacy Example (Old Approach - Creates Multiple Clusters)

**Note:** The `ecs-fargate` module creates a cluster AND a service together. Don't use this for multiple services unless you want multiple clusters.

### Example: Backend API + Worker Service (OLD WAY - NOT RECOMMENDED)

```hcl
# In environments/dev/main.tf

# Backend API Service
module "ecs_backend" {
  source = "../../modules/ecs-fargate"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  target_group_arn  = module.alb_backend.target_group_arn

  container_name  = "backend-api"
  container_image = var.backend_image
  container_port  = 8080

  task_cpu    = "512"
  task_memory = "1024"

  environment_variables = [
    {
      name  = "SERVICE_NAME"
      value = "backend-api"
    },
    {
      name  = "DB_HOST"
      value = module.rds_aurora.cluster_endpoint
    }
  ]

  desired_count            = 2
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 10

  common_tags = local.common_tags
}

# Worker Service (no ALB needed)
module "ecs_worker" {
  source = "../../modules/ecs-fargate"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  target_group_arn  = module.alb.target_group_arn  # Dummy, won't be used

  container_name  = "worker"
  container_image = var.worker_image
  container_port  = 8080  # Not used, but required

  task_cpu    = "256"
  task_memory = "512"

  environment_variables = [
    {
      name  = "SERVICE_NAME"
      value = "worker"
    },
    {
      name  = "QUEUE_URL"
      value = "your-sqs-queue-url"
    }
  ]

  desired_count            = 1
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 5

  common_tags = local.common_tags
}
```

### Multiple ALBs for Different Services

```hcl
# Backend ALB
module "alb_backend" {
  source = "../../modules/alb"

  project_name      = "${var.project_name}-backend"
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id

  target_group_port     = 8080
  health_check_path     = "/api/health"

  common_tags = merge(local.common_tags, { Service = "backend" })
}

# Admin ALB (internal)
module "alb_admin" {
  source = "../../modules/alb"

  project_name      = "${var.project_name}-admin"
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id

  internal              = true  # Internal ALB
  target_group_port     = 3000
  health_check_path     = "/admin/health"

  common_tags = merge(local.common_tags, { Service = "admin" })
}
```

## Approach 2: Path-Based Routing (Single ALB)

Use a single ALB with path-based routing to multiple ECS services.

```hcl
# Main ALB
module "alb" {
  source = "../../modules/alb"

  project_name      = var.project_name
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id

  # Additional target groups for different services
  additional_target_groups = {
    api = {
      port                  = 8080
      protocol              = "HTTP"
      health_check_path     = "/api/health"
    }
    admin = {
      port                  = 3000
      protocol              = "HTTP"
      health_check_path     = "/admin/health"
    }
  }

  # Path-based routing rules
  listener_rules = {
    api = {
      priority         = 100
      target_group_arn = module.alb.additional_target_group_arns["api"]
      path_patterns    = ["/api/*"]
    }
    admin = {
      priority         = 200
      target_group_arn = module.alb.additional_target_group_arns["admin"]
      path_patterns    = ["/admin/*"]
    }
  }

  common_tags = local.common_tags
}

# API Service
module "ecs_api" {
  source = "../../modules/ecs-fargate"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  target_group_arn  = module.alb.additional_target_group_arns["api"]

  container_name  = "api"
  container_image = var.api_image
  container_port  = 8080

  common_tags = merge(local.common_tags, { Service = "api" })
}

# Admin Service
module "ecs_admin" {
  source = "../../modules/ecs-fargate"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  target_group_arn  = module.alb.additional_target_group_arns["admin"]

  container_name  = "admin"
  container_image = var.admin_image
  container_port  = 3000

  common_tags = merge(local.common_tags, { Service = "admin" })
}
```

## Approach 3: Service Discovery with AWS Cloud Map

For service-to-service communication without ALB.

### Step 1: Create Cloud Map Namespace

```hcl
# Add to environments/dev/main.tf

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}-${var.environment}.local"
  description = "Private DNS namespace for service discovery"
  vpc         = module.vpc.vpc_id

  tags = local.common_tags
}
```

### Step 2: Modify ECS Module to Support Service Discovery

Create a new file: `modules/ecs-fargate/service_discovery.tf`

```hcl
# Service Discovery Service
resource "aws_service_discovery_service" "main" {
  count = var.enable_service_discovery ? 1 : 0
  name  = var.service_discovery_name

  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = var.common_tags
}
```

Add to `modules/ecs-fargate/variables.tf`:

```hcl
variable "enable_service_discovery" {
  description = "Enable AWS Cloud Map service discovery"
  type        = bool
  default     = false
}

variable "service_discovery_namespace_id" {
  description = "AWS Cloud Map namespace ID"
  type        = string
  default     = null
}

variable "service_discovery_name" {
  description = "Name for service discovery service"
  type        = string
  default     = null
}
```

Update ECS service in `modules/ecs-fargate/main.tf`:

```hcl
resource "aws_ecs_service" "main" {
  # ... existing configuration ...

  # Add service registries
  dynamic "service_registries" {
    for_each = var.enable_service_discovery ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.main[0].arn
    }
  }
}
```

### Step 3: Use Service Discovery

```hcl
# Backend Service (discoverable)
module "ecs_backend" {
  source = "../../modules/ecs-fargate"

  # ... existing config ...

  enable_service_discovery      = true
  service_discovery_namespace_id = aws_service_discovery_private_dns_namespace.main.id
  service_discovery_name        = "backend"

  # Other services can now connect to: backend.myapp-dev.local
}

# Frontend Service (connects to backend)
module "ecs_frontend" {
  source = "../../modules/ecs-fargate"

  # ... existing config ...

  environment_variables = [
    {
      name  = "BACKEND_URL"
      value = "http://backend.${var.project_name}-${var.environment}.local:8080"
    }
  ]
}
```

## Complete Example: Microservices Architecture

Here's a complete example with multiple services:

```hcl
# environments/dev/main.tf

# ... existing VPC, security groups, RDS modules ...

# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}-${var.environment}.local"
  vpc         = module.vpc.vpc_id
  tags        = local.common_tags
}

# API Gateway Service
module "ecs_api_gateway" {
  source = "../../modules/ecs-fargate"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  target_group_arn  = module.alb.target_group_arn

  container_name  = "api-gateway"
  container_image = "your-ecr-repo/api-gateway:latest"
  container_port  = 8080

  task_cpu    = "512"
  task_memory = "1024"

  enable_service_discovery       = true
  service_discovery_namespace_id = aws_service_discovery_private_dns_namespace.main.id
  service_discovery_name         = "api-gateway"

  desired_count = 2

  common_tags = merge(local.common_tags, { Service = "api-gateway" })
}

# User Service (internal, no ALB)
module "ecs_user_service" {
  source = "../../modules/ecs-fargate"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  target_group_arn  = module.alb.target_group_arn  # Dummy

  container_name  = "user-service"
  container_image = "your-ecr-repo/user-service:latest"
  container_port  = 8080

  task_cpu    = "256"
  task_memory = "512"

  enable_service_discovery       = true
  service_discovery_namespace_id = aws_service_discovery_private_dns_namespace.main.id
  service_discovery_name         = "user-service"

  environment_variables = [
    {
      name  = "DB_HOST"
      value = module.rds_aurora.cluster_endpoint
    }
  ]

  desired_count = 1

  common_tags = merge(local.common_tags, { Service = "user-service" })
}

# Order Service
module "ecs_order_service" {
  source = "../../modules/ecs-fargate"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  target_group_arn  = module.alb.target_group_arn  # Dummy

  container_name  = "order-service"
  container_image = "your-ecr-repo/order-service:latest"
  container_port  = 8080

  task_cpu    = "256"
  task_memory = "512"

  enable_service_discovery       = true
  service_discovery_namespace_id = aws_service_discovery_private_dns_namespace.main.id
  service_discovery_name         = "order-service"

  environment_variables = [
    {
      name  = "DB_HOST"
      value = module.rds_aurora.cluster_endpoint
    },
    {
      name  = "USER_SERVICE_URL"
      value = "http://user-service.${var.project_name}-${var.environment}.local:8080"
    }
  ]

  desired_count = 1

  common_tags = merge(local.common_tags, { Service = "order-service" })
}

# Background Worker
module "ecs_worker" {
  source = "../../modules/ecs-fargate"

  project_name      = var.project_name
  environment       = var.environment
  aws_region        = var.aws_region
  subnet_ids        = module.vpc.private_app_subnet_ids
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  target_group_arn  = module.alb.target_group_arn  # Dummy

  container_name  = "worker"
  container_image = "your-ecr-repo/worker:latest"
  container_port  = 8080

  task_cpu    = "512"
  task_memory = "1024"

  desired_count = 1

  common_tags = merge(local.common_tags, { Service = "worker" })
}
```

## Variables to Add

```hcl
# environments/dev/variables.tf

variable "api_gateway_image" {
  description = "Docker image for API Gateway service"
  type        = string
  default     = "your-ecr-repo/api-gateway:latest"
}

variable "user_service_image" {
  description = "Docker image for User service"
  type        = string
  default     = "your-ecr-repo/user-service:latest"
}

variable "order_service_image" {
  description = "Docker image for Order service"
  type        = string
  default     = "your-ecr-repo/order-service:latest"
}

variable "worker_image" {
  description = "Docker image for Worker service"
  type        = string
  default     = "your-ecr-repo/worker:latest"
}
```

## Best Practices

1. **Use Service Discovery** for internal service-to-service communication
2. **Separate ALBs** for services that need external access with different characteristics
3. **Path-based routing** when services share the same domain
4. **Different task sizes** based on service requirements
5. **Independent scaling** policies for each service
6. **Consistent naming** conventions (e.g., `${project}-${env}-${service}`)

## Monitoring Multiple Services

```hcl
# Add CloudWatch Dashboard for all services
resource "aws_cloudwatch_dashboard" "services" {
  dashboard_name = "${var.project_name}-${var.environment}-services"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average" }],
            ["AWS/ECS", "MemoryUtilization", { stat = "Average" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Services Overview"
        }
      }
    ]
  })
}
```

This approach gives you maximum flexibility to manage multiple ECS services efficiently!
