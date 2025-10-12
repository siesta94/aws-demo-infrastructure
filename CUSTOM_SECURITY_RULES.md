# Adding Custom Security Group Rules

There are **three approaches** to add custom security group rules beyond what the module provides.

## Approach 1: Add Individual Rules (Recommended)

Add specific rules after the security groups module is created using `aws_security_group_rule` resources.

### Example: Allow SSH Access to ECS Tasks

```hcl
# In environments/dev/main.tf

# First, create the standard security groups
module "security_groups" {
  source = "../../modules/security-groups"
  # ... standard config
}

# Then add custom rule
resource "aws_security_group_rule" "ecs_ssh_access" {
  type              = "ingress"
  description       = "SSH access for debugging"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["203.0.113.0/24"]  # Your office IP range
  security_group_id = module.security_groups.ecs_tasks_security_group_id
}
```

### Example: Allow ECS to Access External API

```hcl
resource "aws_security_group_rule" "ecs_external_api" {
  type              = "egress"
  description       = "Allow access to external API"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["192.0.2.0/24"]  # External API IP range
  security_group_id = module.security_groups.ecs_tasks_security_group_id
}
```

### Example: Allow Redis Access

```hcl
# Create Redis security group
resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-${var.environment}-redis-"
  description = "Security group for ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.common_tags,
    { Name = "${var.project_name}-${var.environment}-redis-sg" }
  )
}

# Allow ECS to access Redis
resource "aws_security_group_rule" "redis_from_ecs" {
  type                     = "ingress"
  description              = "Redis from ECS tasks"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = module.security_groups.ecs_tasks_security_group_id
  security_group_id        = aws_security_group.redis.id
}

# Allow Lambda to access Redis
resource "aws_security_group_rule" "redis_from_lambda" {
  type                     = "ingress"
  description              = "Redis from Lambda"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = module.security_groups.lambda_security_group_id
  security_group_id        = aws_security_group.redis.id
}
```

## Approach 2: Create Additional Security Groups

Create completely new security groups for specialized services.

### Example: Admin Panel with Restricted Access

```hcl
# In environments/dev/main.tf

# Create specialized security group
resource "aws_security_group" "admin_panel" {
  name_prefix = "${var.project_name}-${var.environment}-admin-"
  description = "Security group for admin panel (internal only)"
  vpc_id      = module.vpc.vpc_id

  tags = merge(
    local.common_tags,
    { Name = "${var.project_name}-${var.environment}-admin-sg" }
  )
}

# Allow access only from VPN
resource "aws_security_group_rule" "admin_vpn_access" {
  type              = "ingress"
  description       = "Admin access from VPN"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8"]  # Internal VPN range
  security_group_id = aws_security_group.admin_panel.id
}

# Allow outbound to database
resource "aws_security_group_rule" "admin_to_rds" {
  type                     = "egress"
  description              = "Admin to RDS"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.security_groups.rds_security_group_id
  security_group_id        = aws_security_group.admin_panel.id
}

# Update RDS to allow admin access
resource "aws_security_group_rule" "rds_from_admin" {
  type                     = "ingress"
  description              = "RDS from admin panel"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.admin_panel.id
  security_group_id        = module.security_groups.rds_security_group_id
}

# Use both security groups for admin service
module "ecs_admin" {
  source = "../../modules/ecs-service"
  
  cluster_id   = module.ecs_cluster.cluster_id
  cluster_name = module.ecs_cluster.cluster_name
  
  # Use BOTH security groups
  security_group_id = module.security_groups.ecs_tasks_security_group_id
  # Note: If module doesn't support multiple SGs, use the primary one
  # and add rules to allow traffic between them
  
  # ... rest of config
}

# If module only accepts one SG, add rules to connect them
resource "aws_security_group_rule" "admin_to_ecs_tasks" {
  type                     = "ingress"
  description              = "Allow admin panel traffic"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.admin_panel.id
  security_group_id        = module.security_groups.ecs_tasks_security_group_id
}
```

## Approach 3: Extend the Module (Advanced)

Modify the security-groups module to accept additional rules as variables.

### Step 1: Add to `modules/security-groups/variables.tf`

```hcl
variable "additional_ecs_ingress_rules" {
  description = "Additional ingress rules for ECS tasks security group"
  type = list(object({
    description              = string
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_blocks              = optional(list(string))
    source_security_group_id = optional(string)
  }))
  default = []
}

variable "additional_ecs_egress_rules" {
  description = "Additional egress rules for ECS tasks security group"
  type = list(object({
    description              = string
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_blocks              = optional(list(string))
    source_security_group_id = optional(string)
  }))
  default = []
}
```

### Step 2: Add to `modules/security-groups/main.tf`

```hcl
# After the main ECS security group resource, add:

# Additional ingress rules for ECS tasks
resource "aws_security_group_rule" "ecs_additional_ingress" {
  count       = length(var.additional_ecs_ingress_rules)
  type        = "ingress"
  description = var.additional_ecs_ingress_rules[count.index].description
  from_port   = var.additional_ecs_ingress_rules[count.index].from_port
  to_port     = var.additional_ecs_ingress_rules[count.index].to_port
  protocol    = var.additional_ecs_ingress_rules[count.index].protocol

  cidr_blocks              = var.additional_ecs_ingress_rules[count.index].cidr_blocks
  source_security_group_id = var.additional_ecs_ingress_rules[count.index].source_security_group_id

  security_group_id = aws_security_group.ecs_tasks.id
}

# Additional egress rules for ECS tasks
resource "aws_security_group_rule" "ecs_additional_egress" {
  count       = length(var.additional_ecs_egress_rules)
  type        = "egress"
  description = var.additional_ecs_egress_rules[count.index].description
  from_port   = var.additional_ecs_egress_rules[count.index].from_port
  to_port     = var.additional_ecs_egress_rules[count.index].to_port
  protocol    = var.additional_ecs_egress_rules[count.index].protocol

  cidr_blocks              = var.additional_ecs_egress_rules[count.index].cidr_blocks
  source_security_group_id = var.additional_ecs_egress_rules[count.index].source_security_group_id

  security_group_id = aws_security_group.ecs_tasks.id
}
```

### Step 3: Use in Your Environment

```hcl
# In environments/dev/main.tf

module "security_groups" {
  source = "../../modules/security-groups"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = module.vpc.vpc_cidr_block

  # Standard config
  alb_ingress_cidr_blocks = ["0.0.0.0/0"]
  ecs_task_port           = 8080
  rds_port                = 5432

  # Add custom rules
  additional_ecs_ingress_rules = [
    {
      description = "SSH for debugging"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["203.0.113.0/24"]
    },
    {
      description = "Custom app port"
      from_port   = 9000
      to_port     = 9000
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
    }
  ]

  additional_ecs_egress_rules = [
    {
      description = "Access to external API"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["192.0.2.0/24"]
    }
  ]

  common_tags = local.common_tags
}
```

## Real-World Examples

### Example 1: Microservices with Service Mesh

```hcl
# In environments/dev/main.tf

# Standard security groups
module "security_groups" {
  source = "../../modules/security-groups"
  # ... config
}

# Add Consul/Envoy ports for service mesh
resource "aws_security_group_rule" "ecs_consul_http" {
  type              = "ingress"
  description       = "Consul HTTP API"
  from_port         = 8500
  to_port           = 8500
  protocol          = "tcp"
  self              = true
  security_group_id = module.security_groups.ecs_tasks_security_group_id
}

resource "aws_security_group_rule" "ecs_envoy_admin" {
  type              = "ingress"
  description       = "Envoy admin interface"
  from_port         = 19000
  to_port           = 19000
  protocol          = "tcp"
  self              = true
  security_group_id = module.security_groups.ecs_tasks_security_group_id
}

resource "aws_security_group_rule" "ecs_envoy_listener" {
  type              = "ingress"
  description       = "Envoy listener"
  from_port         = 15000
  to_port           = 15000
  protocol          = "tcp"
  self              = true
  security_group_id = module.security_groups.ecs_tasks_security_group_id
}
```

### Example 2: Allow Database Access from Bastion

```hcl
# Bastion security group
resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from office"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    { Name = "${var.project_name}-${var.environment}-bastion-sg" }
  )
}

# Allow bastion to access RDS
resource "aws_security_group_rule" "rds_from_bastion" {
  type                     = "ingress"
  description              = "PostgreSQL from bastion"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = module.security_groups.rds_security_group_id
}
```

### Example 3: Allow Specific Services Different Access

```hcl
# Worker service needs access to S3 VPC endpoint
resource "aws_security_group_rule" "worker_s3_endpoint" {
  type              = "egress"
  description       = "Allow access to S3 VPC endpoint"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  prefix_list_ids   = [data.aws_prefix_list.s3.id]
  security_group_id = module.security_groups.ecs_tasks_security_group_id
}

# Get S3 prefix list
data "aws_prefix_list" "s3" {
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.${var.aws_region}.s3"]
  }
}
```

### Example 4: Development Environment - Wide Open (Not for Production!)

```hcl
# DEV ONLY - Allow all traffic between ECS tasks for debugging
resource "aws_security_group_rule" "ecs_debug_all" {
  count             = var.environment == "dev" ? 1 : 0
  type              = "ingress"
  description       = "Allow all traffic for debugging (DEV ONLY)"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = module.security_groups.ecs_tasks_security_group_id
}
```

## Best Practices

### ✅ DO:
1. **Use Approach 1** (individual rules) for most cases - it's clean and explicit
2. **Add descriptions** to every rule - future you will thank you
3. **Use source security groups** instead of CIDR blocks when possible
4. **Keep rules in the same file** as the resources that need them
5. **Use variables** for repeated values (ports, CIDR blocks)

### ❌ DON'T:
1. Don't modify the security-groups module directly - extend it
2. Don't use `0.0.0.0/0` for ingress unless you need public access
3. Don't add sensitive rules (like SSH) without IP restrictions
4. Don't forget to add the reverse rule when connecting security groups

## Quick Reference

### Allow Service A → Service B

```hcl
# On Service B's security group (allow ingress)
resource "aws_security_group_rule" "b_from_a" {
  type                     = "ingress"
  from_port                = PORT
  to_port                  = PORT
  protocol                 = "tcp"
  source_security_group_id = service_a_sg_id
  security_group_id        = service_b_sg_id
}
```

### Allow Service → Internet (HTTPS)

```hcl
resource "aws_security_group_rule" "service_https_out" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = service_sg_id
}
```

### Allow Specific IP → Service

```hcl
resource "aws_security_group_rule" "service_from_office" {
  type              = "ingress"
  from_port         = PORT
  to_port           = PORT
  protocol          = "tcp"
  cidr_blocks       = ["YOUR_OFFICE_IP/32"]
  security_group_id = service_sg_id
}
```

## Summary

**Recommended Approach:**
- Use the **security-groups module** as-is for standard rules
- Add **individual `aws_security_group_rule`** resources for custom needs
- Create **new security groups** only when you need completely different rule sets

This keeps your infrastructure clean, maintainable, and easy to understand!
