/**
 * Application Load Balancer Module
 * 
 * Creates:
 * - Application Load Balancer
 * - Target groups for ECS services
 * - Listeners (HTTP and HTTPS)
 * - SSL certificate (optional)
 */

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = var.enable_http2
  enable_cross_zone_load_balancing = true
  idle_timeout              = var.idle_timeout

  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = var.access_logs_prefix
    enabled = var.enable_access_logs
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alb"
    }
  )
}

# Target Group for ECS Service
resource "aws_lb_target_group" "main" {
  name_prefix = substr("${var.project_name}-${var.environment}", 0, 6)
  port        = var.target_group_port
  protocol    = var.target_group_protocol
  vpc_id      = var.vpc_id
  target_type = "ip" # For Fargate

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = var.health_check_matcher
    protocol            = var.health_check_protocol
  }

  deregistration_delay = var.deregistration_delay

  stickiness {
    type            = "lb_cookie"
    cookie_duration = var.stickiness_cookie_duration
    enabled         = var.stickiness_enabled
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-tg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb.main]
}

# HTTP Listener (redirect to HTTPS if certificate is provided)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.certificate_arn != null ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.certificate_arn != null ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.certificate_arn == null ? aws_lb_target_group.main.arn : null
  }

  tags = var.common_tags
}

# HTTPS Listener (if certificate is provided)
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != null ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = var.common_tags
}

# Additional Target Groups (for blue-green deployments, etc.)
resource "aws_lb_target_group" "additional" {
  for_each = var.additional_target_groups

  name_prefix = substr(each.key, 0, 6)
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = lookup(each.value, "health_check_healthy_threshold", var.health_check_healthy_threshold)
    unhealthy_threshold = lookup(each.value, "health_check_unhealthy_threshold", var.health_check_unhealthy_threshold)
    timeout             = lookup(each.value, "health_check_timeout", var.health_check_timeout)
    interval            = lookup(each.value, "health_check_interval", var.health_check_interval)
    path                = lookup(each.value, "health_check_path", var.health_check_path)
    matcher             = lookup(each.value, "health_check_matcher", var.health_check_matcher)
    protocol            = lookup(each.value, "health_check_protocol", var.health_check_protocol)
  }

  deregistration_delay = lookup(each.value, "deregistration_delay", var.deregistration_delay)

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-tg-${each.key}"
    }
  )

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb.main]
}

# Listener Rules for path-based routing
resource "aws_lb_listener_rule" "path_based" {
  for_each = var.listener_rules

  listener_arn = var.certificate_arn != null ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = each.value.target_group_arn
  }

  dynamic "condition" {
    for_each = lookup(each.value, "path_patterns", null) != null ? [1] : []
    content {
      path_pattern {
        values = each.value.path_patterns
      }
    }
  }

  dynamic "condition" {
    for_each = lookup(each.value, "host_headers", null) != null ? [1] : []
    content {
      host_header {
        values = each.value.host_headers
      }
    }
  }

  tags = var.common_tags
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "target_response_time" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-alb-target-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.target_response_time_threshold
  alarm_description   = "This metric monitors ALB target response time"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count               = var.enable_cloudwatch_alarms ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy hosts behind ALB"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.main.arn_suffix
  }

  tags = var.common_tags
}
