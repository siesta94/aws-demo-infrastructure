/**
 * Security Groups Module
 * 
 * Creates security groups for:
 * - Application Load Balancer (ALB)
 * - ECS Fargate services
 * - RDS Aurora database
 * - Lambda functions
 */

# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Security Group Rules
resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  description       = "HTTP from anywhere"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.alb_ingress_cidr_blocks
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_https_ingress" {
  type              = "ingress"
  description       = "HTTPS from anywhere"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.alb_ingress_cidr_blocks
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_to_ecs" {
  type                     = "egress"
  description              = "Allow traffic to ECS tasks"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.alb.id
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-tasks-"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ecs-tasks-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ECS Security Group Rules
resource "aws_security_group_rule" "ecs_ingress_from_alb" {
  type                     = "ingress"
  description              = "Allow traffic from ALB"
  from_port                = var.ecs_task_port
  to_port                  = var.ecs_task_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "ecs_ingress_self" {
  type              = "ingress"
  description       = "Allow inter-container communication"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "ecs_egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
}

# Security Group for RDS Aurora
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "Security group for RDS Aurora cluster"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Security Group Rules
resource "aws_security_group_rule" "rds_ingress_from_ecs" {
  type                     = "ingress"
  description              = "PostgreSQL from ECS tasks"
  from_port                = var.rds_port
  to_port                  = var.rds_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_ingress_from_lambda" {
  type                     = "ingress"
  description              = "PostgreSQL from Lambda"
  from_port                = var.rds_port
  to_port                  = var.rds_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_ingress_self" {
  type              = "ingress"
  description       = "Allow RDS cluster communication"
  from_port         = var.rds_port
  to_port           = var.rds_port
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.rds.id
}

# Security Group for Lambda Functions
resource "aws_security_group" "lambda" {
  name_prefix = "${var.project_name}-${var.environment}-lambda-"
  description = "Security group for Lambda functions"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-lambda-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda Security Group Rules
resource "aws_security_group_rule" "lambda_egress_to_rds" {
  type                     = "egress"
  description              = "Allow traffic to RDS"
  from_port                = var.rds_port
  to_port                  = var.rds_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.lambda.id
}

resource "aws_security_group_rule" "lambda_egress_https" {
  type              = "egress"
  description       = "Allow HTTPS to internet"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda.id
}

resource "aws_security_group_rule" "lambda_egress_http" {
  type              = "egress"
  description       = "Allow HTTP to internet"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda.id
}

# Security Group for ElastiCache Redis
resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-${var.environment}-redis-"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-redis-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Redis Security Group Rules
resource "aws_security_group_rule" "redis_ingress_from_ecs" {
  type                     = "ingress"
  description              = "Redis from ECS tasks"
  from_port                = var.redis_port
  to_port                  = var.redis_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.redis.id
}

resource "aws_security_group_rule" "redis_ingress_from_lambda" {
  type                     = "ingress"
  description              = "Redis from Lambda"
  from_port                = var.redis_port
  to_port                  = var.redis_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.redis.id
}

resource "aws_security_group_rule" "redis_ingress_self" {
  type              = "ingress"
  description       = "Allow Redis cluster communication"
  from_port         = var.redis_port
  to_port           = var.redis_port
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.redis.id
}

# Security Group for VPC Endpoints (optional, for AWS service access)
resource "aws_security_group" "vpc_endpoints" {
  count       = var.create_vpc_endpoints_sg ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  # Ingress from VPC
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  # No egress rules needed

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}
