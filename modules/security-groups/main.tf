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

  # HTTP ingress from anywhere
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidr_blocks
  }

  # HTTPS ingress from anywhere
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidr_blocks
  }

  # Egress to ECS tasks
  egress {
    description     = "Allow traffic to ECS tasks"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

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

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-tasks-"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  # Ingress from ALB
  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.ecs_task_port
    to_port         = var.ecs_task_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow inter-container communication
  ingress {
    description = "Allow inter-container communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Egress to anywhere (for external API calls, package downloads, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

# Security Group for RDS Aurora
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "Security group for RDS Aurora cluster"
  vpc_id      = var.vpc_id

  # Ingress from ECS tasks
  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = var.rds_port
    to_port         = var.rds_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  # Ingress from Lambda functions
  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = var.rds_port
    to_port         = var.rds_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  # Allow communication within RDS security group (for read replicas)
  ingress {
    description = "Allow RDS cluster communication"
    from_port   = var.rds_port
    to_port     = var.rds_port
    protocol    = "tcp"
    self        = true
  }

  # No egress rules needed for RDS (it doesn't initiate outbound connections)

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

# Security Group for Lambda Functions
resource "aws_security_group" "lambda" {
  name_prefix = "${var.project_name}-${var.environment}-lambda-"
  description = "Security group for Lambda functions"
  vpc_id      = var.vpc_id

  # Egress to RDS
  egress {
    description     = "Allow traffic to RDS"
    from_port       = var.rds_port
    to_port         = var.rds_port
    protocol        = "tcp"
    security_groups = [aws_security_group.rds.id]
  }

  # Egress to internet (for API calls)
  egress {
    description = "Allow HTTPS to internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress to HTTP (if needed)
  egress {
    description = "Allow HTTP to internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

# Security Group for ElastiCache Redis
resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-${var.environment}-redis-"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  # Ingress from ECS tasks
  ingress {
    description     = "Redis from ECS tasks"
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  # Ingress from Lambda functions
  ingress {
    description     = "Redis from Lambda"
    from_port       = var.redis_port
    to_port         = var.redis_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  # Allow communication within Redis security group (for replication)
  ingress {
    description = "Allow Redis cluster communication"
    from_port   = var.redis_port
    to_port     = var.redis_port
    protocol    = "tcp"
    self        = true
  }

  # No egress rules needed for Redis

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
