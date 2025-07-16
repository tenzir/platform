output "ui_repository_url" {
  description = "URL of the unified UI repository"
  value       = module.bootstrap.ui_repository_url
}

output "platform_api_repository_url" {
  description = "URL of the unified platform API repository"
  value       = module.bootstrap.platform_api_repository_url
}

output "gateway_repository_url" {
  description = "URL of the unified gateway repository"
  value       = module.bootstrap.gateway_repository_url
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
  description = "The OAuth client ID (Cognito or external OIDC)"
  value       = local.oidc_client_id
}

output "oauth_client_secret" {
  description = "The OAuth client secret (Cognito or external OIDC)"
  value       = local.oidc_client_secret
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "The OIDC issuer URL (Cognito or external OIDC)"
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
  value       = module.bootstrap.base_domain
}

output "api_domain" {
  description = "The API domain name"
  value       = module.bootstrap.api_domain
}

output "ui_domain" {
  description = "The UI domain name"
  value       = module.bootstrap.ui_domain
}

output "admin_username" {
  description = "Default admin username for Cognito (only available when using Cognito)"
  value       = var.use_external_oidc ? null : aws_cognito_user.admin[0].username
}

output "admin_initial_password" {
  description = "Initial admin password for Cognito (only available when using Cognito, change after first login)"
  value       = var.use_external_oidc ? null : nonsensitive(random_password.admin_password[0].result)
}

output "oidc_provider_type" {
  description = "The type of OIDC provider being used"
  value       = var.use_external_oidc ? "external" : "cognito"
}


