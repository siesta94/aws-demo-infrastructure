/**
 * Lambda Module
 * 
 * Creates:
 * - Lambda function
 * - IAM role and policies
 * - CloudWatch Log Group
 * - Lambda permissions
 * - VPC configuration (optional)
 */

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.common_tags
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name_prefix = "${var.project_name}-${var.environment}-${var.function_name}-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = var.vpc_config != null ? "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole" : "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Additional IAM policies
resource "aws_iam_role_policy" "lambda_additional" {
  count = var.additional_policy != null ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-${var.function_name}-policy-"
  role        = aws_iam_role.lambda.id
  policy      = var.additional_policy
}

# Lambda function
resource "aws_lambda_function" "main" {
  function_name = "${var.project_name}-${var.environment}-${var.function_name}"
  description   = var.description
  role          = aws_iam_role.lambda.arn
  
  # Deployment package
  filename         = var.filename
  source_code_hash = var.source_code_hash
  s3_bucket        = var.s3_bucket
  s3_key           = var.s3_key
  s3_object_version = var.s3_object_version
  
  # Runtime configuration
  handler          = var.handler
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size
  
  # Environment variables
  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  # Tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  # Reserved concurrent executions
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # Layers
  layers = var.layers

  # Dead letter config
  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn != null ? [1] : []
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  # Ephemeral storage
  ephemeral_storage {
    size = var.ephemeral_storage_size
  }

  # Architecture
  architectures = [var.architecture]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-${var.function_name}"
    }
  )

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic
  ]
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  count         = var.allow_api_gateway ? 1 : 0
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = var.api_gateway_source_arn != null ? "${var.api_gateway_source_arn}/*/*" : null
}

# Lambda Permission for S3
resource "aws_lambda_permission" "s3" {
  count         = var.allow_s3 ? 1 : 0
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_source_bucket_arn
}

# Lambda Permission for CloudWatch Events
resource "aws_lambda_permission" "cloudwatch_events" {
  count         = var.allow_cloudwatch_events ? 1 : 0
  statement_id  = "AllowCloudWatchEventsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "events.amazonaws.com"
  source_arn    = var.cloudwatch_event_rule_arn
}

# Lambda Function URL (optional)
resource "aws_lambda_function_url" "main" {
  count              = var.create_function_url ? 1 : 0
  function_name      = aws_lambda_function.main.function_name
  authorization_type = var.function_url_auth_type

  dynamic "cors" {
    for_each = var.function_url_cors != null ? [var.function_url_cors] : []
    content {
      allow_credentials = cors.value.allow_credentials
      allow_origins     = cors.value.allow_origins
      allow_methods     = cors.value.allow_methods
      allow_headers     = cors.value.allow_headers
      expose_headers    = cors.value.expose_headers
      max_age           = cors.value.max_age
    }
  }
}

# Lambda Alias
resource "aws_lambda_alias" "main" {
  count            = var.create_alias ? 1 : 0
  name             = var.alias_name
  description      = "Alias for ${var.function_name}"
  function_name    = aws_lambda_function.main.function_name
  function_version = var.alias_function_version

  dynamic "routing_config" {
    for_each = var.alias_routing_config != null ? [var.alias_routing_config] : []
    content {
      additional_version_weights = routing_config.value.additional_version_weights
    }
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "errors" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-${var.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "This metric monitors Lambda function errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "throttles" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-${var.function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors Lambda function throttles"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "duration" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-${var.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.timeout * 1000 * 0.8 # 80% of timeout in milliseconds
  alarm_description   = "This metric monitors Lambda function duration"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  tags = var.common_tags
}
