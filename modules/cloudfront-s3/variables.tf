/**
 * CloudFront + S3 Module Variables
 */

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for S3 encryption"
  type        = string
  default     = null
}

variable "enable_lifecycle_rules" {
  description = "Enable S3 lifecycle rules"
  type        = bool
  default     = true
}

variable "noncurrent_version_expiration_days" {
  description = "Number of days after which to expire noncurrent versions"
  type        = number
  default     = 90
}

variable "enable_intelligent_tiering" {
  description = "Enable intelligent tiering for S3 objects"
  type        = bool
  default     = false
}

variable "enable_ipv6" {
  description = "Enable IPv6 for CloudFront"
  type        = bool
  default     = true
}

variable "default_root_object" {
  description = "Default root object for CloudFront"
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "domain_names" {
  description = "List of custom domain names for CloudFront"
  type        = list(string)
  default     = []
}

variable "web_acl_id" {
  description = "AWS WAF Web ACL ID to associate with CloudFront"
  type        = string
  default     = null
}

variable "forward_headers" {
  description = "Headers to forward to origin"
  type        = list(string)
  default     = []
}

variable "min_ttl" {
  description = "Minimum TTL for CloudFront cache"
  type        = number
  default     = 0
}

variable "default_ttl" {
  description = "Default TTL for CloudFront cache"
  type        = number
  default     = 3600
}

variable "max_ttl" {
  description = "Maximum TTL for CloudFront cache"
  type        = number
  default     = 86400
}

variable "lambda_edge_viewer_request_arn" {
  description = "ARN of Lambda@Edge function for viewer requests"
  type        = string
  default     = null
}

variable "cloudfront_function_arn" {
  description = "ARN of CloudFront function for viewer requests"
  type        = string
  default     = null
}

variable "custom_error_responses" {
  description = "Custom error responses for CloudFront"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = [
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]
}

variable "geo_restriction_type" {
  description = "Type of geo restriction (none, whitelist, blacklist)"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restriction"
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for custom domain"
  type        = string
  default     = null
}

variable "minimum_protocol_version" {
  description = "Minimum SSL/TLS protocol version"
  type        = string
  default     = "TLSv1.2_2021"
}

variable "enable_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

variable "logging_bucket" {
  description = "S3 bucket for CloudFront logs (uses auto-created bucket if not provided)"
  type        = string
  default     = null
}

variable "logging_prefix" {
  description = "Prefix for CloudFront log files"
  type        = string
  default     = "cloudfront/"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudFront logs"
  type        = number
  default     = 90
}

variable "create_route53_records" {
  description = "Create Route53 DNS records for custom domains"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
  default     = null
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for monitoring"
  type        = bool
  default     = true
}

variable "error_rate_threshold" {
  description = "Error rate threshold for CloudWatch alarm (percentage)"
  type        = number
  default     = 5
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
