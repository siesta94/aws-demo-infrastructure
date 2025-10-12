/**
 * CloudFront + S3 Module
 * 
 * Creates:
 * - S3 bucket for static website hosting
 * - CloudFront distribution
 * - Origin Access Identity (OAI)
 * - S3 bucket policies
 * - Optional custom domain and SSL certificate
 */

# S3 Bucket for static website
resource "aws_s3_bucket" "frontend" {
  bucket_prefix = "${var.project_name}-${var.environment}-frontend-"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-frontend-bucket"
    }
  )
}

# Block all public access to S3 bucket
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
  }
}

# Lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  count  = var.enable_lifecycle_rules ? 1 : 0
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "transition-to-ia"
    status = var.enable_intelligent_tiering ? "Enabled" : "Disabled"

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "main" {
  comment = "OAI for ${var.project_name}-${var.environment} frontend"
}

# S3 bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.main.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  comment             = "${var.project_name}-${var.environment} frontend distribution"
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = var.domain_names
  web_acl_id          = var.web_acl_id

  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false
      headers      = var.forward_headers

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = var.min_ttl
    default_ttl            = var.default_ttl
    max_ttl                = var.max_ttl
    compress               = true

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = var.lambda_edge_viewer_request_arn != null ? var.lambda_edge_viewer_request_arn : null
      include_body = false
    }

    dynamic "function_association" {
      for_each = var.cloudfront_function_arn != null ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = var.cloudfront_function_arn
      }
    }
  }

  # Custom error responses for SPA
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null ? true : false
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != null ? var.minimum_protocol_version : null
  }

  logging_config {
    bucket          = var.logging_bucket != null ? var.logging_bucket : null
    prefix          = var.logging_prefix
    include_cookies = false
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-cloudfront"
    }
  )
}

# S3 bucket for CloudFront logs (optional)
resource "aws_s3_bucket" "logs" {
  count         = var.enable_logging && var.logging_bucket == null ? 1 : 0
  bucket_prefix = "${var.project_name}-${var.environment}-cf-logs-"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-cloudfront-logs"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count  = var.enable_logging && var.logging_bucket == null ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count  = var.enable_logging && var.logging_bucket == null ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }
  }
}

# Route53 DNS records (if domain names are provided)
resource "aws_route53_record" "main" {
  for_each = toset(var.create_route53_records && length(var.domain_names) > 0 ? var.domain_names : [])

  zone_id = var.route53_zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# CloudWatch Alarms for CloudFront
resource "aws_cloudwatch_metric_alarm" "error_rate" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-cloudfront-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = "300"
  statistic           = "Average"
  threshold           = var.error_rate_threshold
  alarm_description   = "This metric monitors CloudFront 4xx error rate"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main.id
  }

  tags = var.common_tags
}
