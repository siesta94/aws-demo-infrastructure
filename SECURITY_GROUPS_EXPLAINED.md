# Security Groups Module Explained

## How It Works

The **Security Groups module creates ALL security groups at once** in a single module call. This is a smart design because it handles all the interdependencies between security groups automatically.

## What Gets Created

When you call the security-groups module **once**, it creates:

```
module "security_groups" {
  source = "../../modules/security-groups"
  # ... config
}
```

### Created Security Groups:

1. ✅ **ALB Security Group** - For Application Load Balancer
2. ✅ **ECS Tasks Security Group** - For all ECS containers
3. ✅ **RDS Security Group** - For database
4. ✅ **Lambda Security Group** - For Lambda functions
5. ✅ **VPC Endpoints Security Group** (optional) - For AWS service endpoints

## Visual Architecture

```
Internet
   ↓ (HTTP/HTTPS)
┌──────────────────┐
│  ALB SG          │ ← Port 80, 443 from 0.0.0.0/0
│  (Public)        │
└────────┬─────────┘
         ↓ (Port 8080)
┌──────────────────┐
│  ECS Tasks SG    │ ← Port 8080 from ALB SG
│  (Private)       │ ← Self-referencing (inter-service)
└────┬────┬────────┘
     │    │ (Port 5432)
     │    ↓
     │  ┌──────────────────┐
     │  │  RDS SG          │ ← Port 5432 from ECS Tasks SG
     │  │  (Private)       │ ← Port 5432 from Lambda SG
     │  └──────────────────┘
     │
     ↓ (Port 5432)
┌──────────────────┐
│  Lambda SG       │ ← No ingress (Lambda doesn't accept connections)
│  (Private)       │ → Port 5432 to RDS SG
└──────────────────┘ → Port 443 to Internet (API calls)
```

## How Rules Are Configured

### 1. ALB Security Group
```hcl
# Allows traffic IN from internet
Ingress:
  - Port 80 (HTTP) from 0.0.0.0/0
  - Port 443 (HTTPS) from 0.0.0.0/0

# Allows traffic OUT to ECS tasks
Egress:
  - All ports to ECS Tasks SG
```

### 2. ECS Tasks Security Group
```hcl
# Allows traffic IN from ALB
Ingress:
  - Port 8080 from ALB SG
  - All ports from itself (inter-container communication)

# Allows traffic OUT anywhere (for API calls, downloads, etc.)
Egress:
  - All traffic to 0.0.0.0/0
```

### 3. RDS Security Group
```hcl
# Allows traffic IN from ECS and Lambda
Ingress:
  - Port 5432 from ECS Tasks SG
  - Port 5432 from Lambda SG
  - Port 5432 from itself (for read replicas)

# No egress rules (databases don't initiate connections)
Egress:
  - None
```

### 4. Lambda Security Group
```hcl
# No ingress (Lambda doesn't accept incoming connections)
Ingress:
  - None

# Allows traffic OUT to RDS and internet
Egress:
  - Port 5432 to RDS SG
  - Port 443 to 0.0.0.0/0 (HTTPS for API calls)
  - Port 80 to 0.0.0.0/0 (HTTP if needed)
```

## Cross-References Between Security Groups

The module cleverly handles dependencies:

```hcl
# ALB SG references ECS SG (created in same module)
resource "aws_security_group" "alb" {
  egress {
    security_groups = [aws_security_group.ecs_tasks.id]  # ← References ECS SG
  }
}

# ECS SG references ALB SG
resource "aws_security_group" "ecs_tasks" {
  ingress {
    security_groups = [aws_security_group.alb.id]  # ← References ALB SG
  }
}

# RDS SG references both ECS and Lambda SGs
resource "aws_security_group" "rds" {
  ingress {
    security_groups = [
      aws_security_group.ecs_tasks.id,    # ← ECS can connect
      aws_security_group.lambda.id        # ← Lambda can connect
    ]
  }
}
```

## How to Use It

### Step 1: Call Module Once

```hcl
# In environments/dev/main.tf

module "security_groups" {
  source = "../../modules/security-groups"

  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = module.vpc.vpc_cidr_block

  # Configuration
  alb_ingress_cidr_blocks = ["0.0.0.0/0"]  # Allow from internet
  ecs_task_port           = 8080
  rds_port                = 5432

  common_tags = local.common_tags
}
```

### Step 2: Use the Outputs

The module provides IDs for all created security groups:

```hcl
# Use in ALB module
module "alb" {
  source = "../../modules/alb"
  
  security_group_id = module.security_groups.alb_security_group_id  # ← ALB SG
  # ...
}

# Use in ECS service
module "ecs_backend" {
  source = "../../modules/ecs-service"
  
  security_group_id = module.security_groups.ecs_tasks_security_group_id  # ← ECS SG
  # ...
}

# Use in RDS
module "rds_aurora" {
  source = "../../modules/rds-aurora"
  
  security_group_id = module.security_groups.rds_security_group_id  # ← RDS SG
  # ...
}

# Use in Lambda
module "lambda_api" {
  source = "../../modules/lambda"
  
  vpc_config = {
    subnet_ids         = module.vpc.private_app_subnet_ids
    security_group_ids = [module.security_groups.lambda_security_group_id]  # ← Lambda SG
  }
  # ...
}
```

## Key Benefits of This Design

### ✅ Single Source of Truth
All security groups are defined in one place, making it easy to understand the security architecture.

### ✅ Automatic Dependencies
Cross-references between security groups are handled automatically within the module.

### ✅ No Circular Dependencies
Because all SGs are created in the same module, Terraform can resolve the dependencies correctly.

### ✅ Consistent Naming
All security groups follow the same naming convention: `${project_name}-${environment}-${type}-sg`

### ✅ Easy to Customize
You can modify ports, CIDR blocks, and add custom rules through variables.

## Customization Examples

### 1. Restrict ALB Access to Specific IPs

```hcl
module "security_groups" {
  source = "../../modules/security-groups"
  
  alb_ingress_cidr_blocks = [
    "203.0.113.0/24",  # Office IP range
    "198.51.100.0/24"  # VPN IP range
  ]
  # ...
}
```

### 2. Use Different Database Port

```hcl
module "security_groups" {
  source = "../../modules/security-groups"
  
  rds_port = 3306  # For MySQL instead of PostgreSQL
  # ...
}
```

### 3. Use Different ECS Port

```hcl
module "security_groups" {
  source = "../../modules/security-groups"
  
  ecs_task_port = 3000  # For Node.js app
  # ...
}
```

## Multiple Services Scenario

**Q: If I have multiple ECS services, do they all use the same security group?**

**A: Yes!** All ECS services share the same `ecs_tasks_security_group_id`. This is fine because:

1. The security group allows **self-referencing** (services can talk to each other)
2. All services need similar access patterns (to RDS, to internet)
3. It simplifies management

However, if you need **different security rules** for different services, you have options:

### Option 1: Add Custom Rules After Module

```hcl
# After creating security_groups module
resource "aws_security_group_rule" "admin_restricted" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8"]  # Internal only
  security_group_id = module.security_groups.ecs_tasks_security_group_id
}
```

### Option 2: Create Additional Security Groups

```hcl
# Create a specialized SG for admin service
resource "aws_security_group" "admin" {
  name_prefix = "${var.project_name}-${var.environment}-admin-"
  vpc_id      = module.vpc.vpc_id

  # Custom rules for admin
  # ...
}

# Use both SGs for admin service
module "ecs_admin" {
  source = "../../modules/ecs-service"
  
  security_group_ids = [
    module.security_groups.ecs_tasks_security_group_id,  # Base SG
    aws_security_group.admin.id                          # Additional SG
  ]
}
```

## Troubleshooting

### Issue: Can't Connect to Database

**Check:**
1. ECS tasks are using `ecs_tasks_security_group_id`
2. RDS is using `rds_security_group_id`
3. Both are in the correct subnets

### Issue: ALB Can't Reach ECS Tasks

**Check:**
1. ALB is using `alb_security_group_id`
2. ECS tasks are using `ecs_tasks_security_group_id`
3. The `ecs_task_port` variable matches your container port

### Issue: Lambda Can't Access RDS

**Check:**
1. Lambda is in VPC with `vpc_config`
2. Lambda is using `lambda_security_group_id`
3. Lambda is in private subnets with NAT gateway

## Summary

The Security Groups module is a **"create all at once"** approach that:

✅ Creates 4-5 security groups in one module call
✅ Handles all cross-references automatically
✅ Provides clean outputs for use in other modules
✅ Follows security best practices
✅ Makes it easy to manage the entire security architecture

You call it **once** per environment, and it sets up all the security groups with proper rules and dependencies!
