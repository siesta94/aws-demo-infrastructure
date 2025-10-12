/**
 * API Gateway Module Variables
 */

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "description" {
  description = "Description of the API Gateway"
  type        = string
  default     = ""
}

variable "endpoint_type" {
  description = "Type of API Gateway endpoint (REGIONAL, EDGE, PRIVATE)"
  type        = string
  default     = "REGIONAL"
}

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "v1"
}

variable "create_proxy_resource" {
  description = "Create a proxy resource for Lambda integration"
  type        = bool
  default     = true
}

variable "authorization_type" {
  description = "Type of authorization (NONE, AWS_IAM, CUSTOM, COGNITO_USER_POOLS)"
  type        = string
  default     = "NONE"
}

variable "authorizer_id" {
  description = "ID of the authorizer to use"
  type        = string
  default     = null
}

variable "api_key_required" {
  description = "Whether API key is required"
  type        = bool
  default     = false
}

variable "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda function for integration"
  type        = string
  default     = null
}

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "enable_access_logs" {
  description = "Enable access logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_metrics" {
  description = "Enable CloudWatch metrics"
  type        = bool
  default     = true
}

variable "logging_level" {
  description = "Logging level (OFF, ERROR, INFO)"
  type        = string
  default     = "INFO"
}

variable "data_trace_enabled" {
  description = "Enable data trace logging"
  type        = bool
  default     = false
}

variable "throttling_burst_limit" {
  description = "Throttling burst limit"
  type        = number
  default     = 5000
}

variable "throttling_rate_limit" {
  description = "Throttling rate limit"
  type        = number
  default     = 10000
}

variable "caching_enabled" {
  description = "Enable caching"
  type        = bool
  default     = false
}

variable "cache_ttl_in_seconds" {
  description = "Cache TTL in seconds"
  type        = number
  default     = 300
}

variable "create_api_key" {
  description = "Create an API key"
  type        = bool
  default     = false
}

variable "create_usage_plan" {
  description = "Create a usage plan"
  type        = bool
  default     = false
}

variable "usage_plan_quota_limit" {
  description = "Maximum number of requests per period"
  type        = number
  default     = 10000
}

variable "usage_plan_quota_period" {
  description = "Time period for quota (DAY, WEEK, MONTH)"
  type        = string
  default     = "MONTH"
}

variable "usage_plan_burst_limit" {
  description = "API burst limit for usage plan"
  type        = number
  default     = 5000
}

variable "usage_plan_rate_limit" {
  description = "API rate limit for usage plan"
  type        = number
  default     = 10000
}

variable "domain_name" {
  description = "Custom domain name for the API"
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ARN of ACM certificate for custom domain"
  type        = string
  default     = null
}

variable "security_policy" {
  description = "Security policy for custom domain (TLS_1_0, TLS_1_2)"
  type        = string
  default     = "TLS_1_2"
}

variable "base_path" {
  description = "Base path for API mapping"
  type        = string
  default     = ""
}

variable "create_route53_record" {
  description = "Create Route53 DNS record for custom domain"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = null
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "error_4xx_threshold" {
  description = "Threshold for 4xx errors alarm"
  type        = number
  default     = 50
}

variable "error_5xx_threshold" {
  description = "Threshold for 5xx errors alarm"
  type        = number
  default     = 10
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
