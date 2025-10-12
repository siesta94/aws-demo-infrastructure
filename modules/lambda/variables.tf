/**
 * Lambda Module Variables
 */

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = ""
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.11"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Amount of memory in MB allocated to Lambda function"
  type        = number
  default     = 128
}

variable "filename" {
  description = "Path to the function's deployment package within the local filesystem"
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the package file"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the function's deployment package"
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of the function's deployment package"
  type        = string
  default     = null
}

variable "s3_object_version" {
  description = "Object version containing the function's deployment package"
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "vpc_config" {
  description = "VPC configuration for Lambda function"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "enable_xray_tracing" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "reserved_concurrent_executions" {
  description = "Amount of reserved concurrent executions for this Lambda function"
  type        = number
  default     = -1
}

variable "layers" {
  description = "List of Lambda Layer Version ARNs to attach to the function"
  type        = list(string)
  default     = []
}

variable "dead_letter_target_arn" {
  description = "ARN of an SNS topic or SQS queue for dead letter queue"
  type        = string
  default     = null
}

variable "ephemeral_storage_size" {
  description = "Amount of ephemeral storage (/tmp) in MB (512 to 10240)"
  type        = number
  default     = 512
}

variable "architecture" {
  description = "Instruction set architecture (x86_64 or arm64)"
  type        = string
  default     = "x86_64"
}

variable "additional_policy" {
  description = "Additional IAM policy document for Lambda execution role"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "allow_api_gateway" {
  description = "Allow API Gateway to invoke this Lambda function"
  type        = bool
  default     = false
}

variable "api_gateway_source_arn" {
  description = "Source ARN of the API Gateway REST API"
  type        = string
  default     = null
}

variable "allow_s3" {
  description = "Allow S3 to invoke this Lambda function"
  type        = bool
  default     = false
}

variable "s3_source_bucket_arn" {
  description = "ARN of the S3 bucket that can invoke this function"
  type        = string
  default     = null
}

variable "allow_cloudwatch_events" {
  description = "Allow CloudWatch Events to invoke this Lambda function"
  type        = bool
  default     = false
}

variable "cloudwatch_event_rule_arn" {
  description = "ARN of the CloudWatch Event Rule"
  type        = string
  default     = null
}

variable "create_function_url" {
  description = "Create a Lambda function URL"
  type        = bool
  default     = false
}

variable "function_url_auth_type" {
  description = "Type of authentication for function URL (NONE or AWS_IAM)"
  type        = string
  default     = "AWS_IAM"
}

variable "function_url_cors" {
  description = "CORS configuration for function URL"
  type = object({
    allow_credentials = optional(bool)
    allow_origins     = optional(list(string))
    allow_methods     = optional(list(string))
    allow_headers     = optional(list(string))
    expose_headers    = optional(list(string))
    max_age           = optional(number)
  })
  default = null
}

variable "create_alias" {
  description = "Create a Lambda alias"
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Name for the alias"
  type        = string
  default     = "live"
}

variable "alias_function_version" {
  description = "Lambda function version to point the alias to"
  type        = string
  default     = "$LATEST"
}

variable "alias_routing_config" {
  description = "Routing configuration for the alias"
  type = object({
    additional_version_weights = map(number)
  })
  default = null
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "error_threshold" {
  description = "Error count threshold for CloudWatch alarm"
  type        = number
  default     = 5
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
