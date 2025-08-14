output "lambda_ui_container_repository_url" {
  description = "URL of the Lambda UI container repository"
  value       = module.bootstrap.lambda_ui_container_repository_url
}

output "lambda_api_container_repository_url" {
  description = "URL of the Lambda API container repository"
  value       = module.bootstrap.lambda_api_container_repository_url
}

output "ui_service_url" {
  description = "URL of the App Runner UI service"
  value       = aws_apprunner_service.ui.service_url
}

output "api_function_url" {
  description = "URL of the API Lambda function"
  value       = aws_lambda_function_url.api_function_url.function_url
}


output "oauth_client_id" {
  description = "The OAuth client ID"
  value       = aws_cognito_user_pool_client.app_client.id
}

output "oauth_client_secret" {
  description = "The OAuth client secret"
  value       = aws_cognito_user_pool_client.app_client.client_secret
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

output "base_domain" {
  description = "The base domain (with random subdomain if enabled)"
  value       = local.base_domain
}

output "api_domain" {
  description = "The API domain name"
  value       = local.api_domain
}

output "ui_domain" {
  description = "The UI domain name"
  value       = local.ui_domain
}

output "admin_username" {
  description = "Default admin username for Cognito"
  value       = aws_cognito_user.admin.username
}

output "admin_initial_password" {
  description = "Initial admin password for Cognito (change after first login)"
  value       = nonsensitive(random_password.admin_password.result)
}


