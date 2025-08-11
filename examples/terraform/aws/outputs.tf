output "lambda_ui_container_repository_url" {
  description = "URL of the Lambda UI container repository"
  value       = module.bootstrap.lambda_ui_container_repository_url
}

output "lambda_api_container_repository_url" {
  description = "URL of the Lambda API container repository"
  value       = module.bootstrap.lambda_api_container_repository_url
}

output "ui_function_url" {
  description = "URL of the UI Lambda function"
  value       = aws_lambda_function_url.ui_function_url.function_url
}

output "api_function_url" {
  description = "URL of the API Lambda function"
  value       = aws_lambda_function_url.api_function_url.function_url
}

output "ecr_pull_through_cache_role_arn" {
  description = "ARN of the ECR pull-through cache role"
  value       = aws_iam_role.ecr_pull_through_cache.arn
}

output "oauth_client_id" {
  description = "The OAuth client ID"
  value       = aws_cognito_user_pool_client.oauth_client.id
}

output "oauth_client_secret" {
  description = "The OAuth client secret"
  value       = aws_cognito_user_pool_client.oauth_client.client_secret
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL for the Cognito User Pool"
  value       = local.oidc_issuer_url
}

output "gateway_alb_dns_name" {
  description = "DNS name of the gateway Application Load Balancer"
  value       = aws_lb.gateway.dns_name
}

output "gateway_alb_hosted_zone_id" {
  description = "Hosted zone ID of the gateway Application Load Balancer"
  value       = aws_lb.gateway.zone_id
}

