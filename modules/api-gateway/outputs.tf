/**
 * API Gateway Module Outputs
 */

output "api_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_arn" {
  description = "ARN of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_execution_arn" {
  description = "Execution ARN of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_root_resource_id" {
  description = "Root resource ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.root_resource_id
}

output "stage_arn" {
  description = "ARN of the API Gateway stage"
  value       = aws_api_gateway_stage.main.arn
}

output "stage_invoke_url" {
  description = "Invoke URL of the API Gateway stage"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "deployment_id" {
  description = "ID of the API Gateway deployment"
  value       = aws_api_gateway_deployment.main.id
}

output "api_key_id" {
  description = "ID of the API key"
  value       = var.create_api_key ? aws_api_gateway_api_key.main[0].id : null
}

output "api_key_value" {
  description = "Value of the API key"
  value       = var.create_api_key ? aws_api_gateway_api_key.main[0].value : null
  sensitive   = true
}

output "usage_plan_id" {
  description = "ID of the usage plan"
  value       = var.create_usage_plan ? aws_api_gateway_usage_plan.main[0].id : null
}

output "domain_name" {
  description = "Custom domain name"
  value       = var.domain_name != null ? aws_api_gateway_domain_name.main[0].domain_name : null
}

output "domain_name_regional_domain" {
  description = "Regional domain name of the custom domain"
  value       = var.domain_name != null ? aws_api_gateway_domain_name.main[0].regional_domain_name : null
}

output "domain_name_regional_zone_id" {
  description = "Regional zone ID of the custom domain"
  value       = var.domain_name != null ? aws_api_gateway_domain_name.main[0].regional_zone_id : null
}
