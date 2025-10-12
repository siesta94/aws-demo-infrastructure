/**
 * Application Load Balancer Module Variables
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
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "internal" {
  description = "Whether the load balancer is internal or internet-facing"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = true
}

variable "enable_http2" {
  description = "Enable HTTP/2 protocol"
  type        = bool
  default     = true
}

variable "idle_timeout" {
  description = "Time in seconds that the connection is allowed to be idle"
  type        = number
  default     = 60
}

variable "enable_access_logs" {
  description = "Enable access logs for the ALB"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "S3 bucket prefix for ALB access logs"
  type        = string
  default     = ""
}

variable "target_group_port" {
  description = "Port on which targets receive traffic"
  type        = number
  default     = 8080
}

variable "target_group_protocol" {
  description = "Protocol to use for routing traffic to targets"
  type        = string
  default     = "HTTP"
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}

variable "health_check_protocol" {
  description = "Protocol for health check"
  type        = string
  default     = "HTTP"
}

variable "health_check_matcher" {
  description = "HTTP codes to use when checking for a successful response"
  type        = string
  default     = "200"
}

variable "health_check_interval" {
  description = "Approximate amount of time between health checks"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Amount of time to wait when receiving a response from the health check"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required"
  type        = number
  default     = 3
}

variable "deregistration_delay" {
  description = "Time to wait before deregistering a target"
  type        = number
  default     = 30
}

variable "stickiness_enabled" {
  description = "Enable sticky sessions"
  type        = bool
  default     = false
}

variable "stickiness_cookie_duration" {
  description = "Time period during which requests are routed to the same target"
  type        = number
  default     = 86400
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
}

variable "additional_target_groups" {
  description = "Map of additional target groups to create"
  type = map(object({
    port                            = number
    protocol                        = string
    health_check_path               = optional(string)
    health_check_protocol           = optional(string)
    health_check_matcher            = optional(string)
    health_check_interval           = optional(number)
    health_check_timeout            = optional(number)
    health_check_healthy_threshold  = optional(number)
    health_check_unhealthy_threshold = optional(number)
    deregistration_delay            = optional(number)
  }))
  default = {}
}

variable "listener_rules" {
  description = "Map of listener rules for path-based routing"
  type = map(object({
    priority         = number
    target_group_arn = string
    path_patterns    = optional(list(string))
    host_headers     = optional(list(string))
  }))
  default = {}
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "target_response_time_threshold" {
  description = "Target response time threshold for CloudWatch alarm (seconds)"
  type        = number
  default     = 1
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
