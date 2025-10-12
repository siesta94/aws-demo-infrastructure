/**
 * API Gateway Module
 * 
 * Creates:
 * - API Gateway REST API
 * - Resources and methods
 * - Lambda integrations
 * - Deployment and stage
 * - CloudWatch logging
 * - API keys and usage plans (optional)
 */

# API Gateway REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-${var.environment}-api"
  description = var.description

  endpoint_configuration {
    types = [var.endpoint_type]
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-api"
    }
  )
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}

# IAM Role for API Gateway CloudWatch Logging
resource "aws_iam_role" "api_gateway_cloudwatch" {
  count       = var.enable_access_logs ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-apigw-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  count      = var.enable_access_logs ? 1 : 0
  role       = aws_iam_role.api_gateway_cloudwatch[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# API Gateway Account (for CloudWatch logging)
resource "aws_api_gateway_account" "main" {
  count               = var.enable_access_logs ? 1 : 0
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch[0].arn
}

# API Gateway Resources
resource "aws_api_gateway_resource" "proxy" {
  count       = var.create_proxy_resource ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "{proxy+}"
}

# API Gateway Method for proxy
resource "aws_api_gateway_method" "proxy" {
  count         = var.create_proxy_resource ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.proxy[0].id
  http_method   = "ANY"
  authorization = var.authorization_type
  authorizer_id = var.authorizer_id
  api_key_required = var.api_key_required
}

# Lambda Integration for proxy
resource "aws_api_gateway_integration" "proxy" {
  count                   = var.create_proxy_resource && var.lambda_function_invoke_arn != null ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.proxy[0].id
  http_method             = aws_api_gateway_method.proxy[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arn
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.main.body,
      aws_api_gateway_resource.proxy,
      aws_api_gateway_method.proxy,
      aws_api_gateway_integration.proxy,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.proxy,
    aws_api_gateway_integration.proxy
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name

  xray_tracing_enabled = var.enable_xray_tracing

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      caller                  = "$context.identity.caller"
      user                    = "$context.identity.user"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${var.stage_name}"
    }
  )
}

# Method Settings
resource "aws_api_gateway_method_settings" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = var.enable_metrics
    logging_level          = var.logging_level
    data_trace_enabled     = var.data_trace_enabled
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
    caching_enabled        = var.caching_enabled
    cache_ttl_in_seconds   = var.cache_ttl_in_seconds
  }
}

# API Key
resource "aws_api_gateway_api_key" "main" {
  count   = var.create_api_key ? 1 : 0
  name    = "${var.project_name}-${var.environment}-api-key"
  enabled = true

  tags = var.common_tags
}

# Usage Plan
resource "aws_api_gateway_usage_plan" "main" {
  count       = var.create_usage_plan ? 1 : 0
  name        = "${var.project_name}-${var.environment}-usage-plan"
  description = "Usage plan for ${var.project_name} ${var.environment}"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = var.usage_plan_quota_limit
    period = var.usage_plan_quota_period
  }

  throttle_settings {
    burst_limit = var.usage_plan_burst_limit
    rate_limit  = var.usage_plan_rate_limit
  }

  tags = var.common_tags
}

# Usage Plan Key
resource "aws_api_gateway_usage_plan_key" "main" {
  count         = var.create_api_key && var.create_usage_plan ? 1 : 0
  key_id        = aws_api_gateway_api_key.main[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main[0].id
}

# Custom Domain Name (optional)
resource "aws_api_gateway_domain_name" "main" {
  count                    = var.domain_name != null ? 1 : 0
  domain_name              = var.domain_name
  regional_certificate_arn = var.certificate_arn
  security_policy          = var.security_policy

  endpoint_configuration {
    types = [var.endpoint_type]
  }

  tags = var.common_tags
}

# Base Path Mapping
resource "aws_api_gateway_base_path_mapping" "main" {
  count       = var.domain_name != null ? 1 : 0
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  domain_name = aws_api_gateway_domain_name.main[0].domain_name
  base_path   = var.base_path
}

# Route53 Record for custom domain
resource "aws_route53_record" "api" {
  count   = var.create_route53_record && var.domain_name != null ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.main[0].regional_domain_name
    zone_id                = aws_api_gateway_domain_name.main[0].regional_zone_id
    evaluate_target_health = false
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_4xx_threshold
  alarm_description   = "This metric monitors API Gateway 4xx errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_5xx_threshold
  alarm_description   = "This metric monitors API Gateway 5xx errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = var.common_tags
}
