/**
 * Security Groups Module Variables
 */

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ecs_task_port" {
  description = "Port on which ECS tasks listen"
  type        = number
  default     = 8080
}

variable "rds_port" {
  description = "Port on which RDS listens"
  type        = number
  default     = 5432
}

variable "create_vpc_endpoints_sg" {
  description = "Whether to create security group for VPC endpoints"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
