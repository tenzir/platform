# ECR Repository outputs
output "node_repository_url" {
  description = "URL of the node repository"
  value       = aws_ecr_repository.node.repository_url
}

output "platform_api_repository_url" {
  description = "URL of the unified platform API repository"
  value       = aws_ecr_repository.platform_api.repository_url
}

output "gateway_repository_url" {
  description = "URL of the unified gateway repository"
  value       = aws_ecr_repository.gateway.repository_url
}

output "ui_repository_url" {
  description = "URL of the unified UI repository"
  value       = aws_ecr_repository.ui.repository_url
}

# Domain outputs
output "base_domain" {
  description = "The base domain for the deployment"
  value       = local.base_domain
}

output "api_domain" {
  description = "The API domain"
  value       = local.api_domain
}

output "ui_domain" {
  description = "The UI domain"
  value       = local.ui_domain
}

output "nodes_domain" {
  description = "The nodes domain"
  value       = local.nodes_domain
}

# Route53 Zone
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

# ACM Certificate outputs (raw certificates, validation handled in main config)
output "api_certificate_arn" {
  description = "ARN of the API certificate"
  value       = aws_acm_certificate.api.arn
}

output "ui_certificate_arn" {
  description = "ARN of the UI certificate"  
  value       = aws_acm_certificate.ui.arn
}

output "nodes_certificate_arn" {
  description = "ARN of the nodes certificate"
  value       = aws_acm_certificate.nodes.arn
}

# Certificate domain validation options (for validation records in main config)
output "api_certificate_domain_validation_options" {
  description = "Domain validation options for API certificate"
  value       = aws_acm_certificate.api.domain_validation_options
}

output "ui_certificate_domain_validation_options" {
  description = "Domain validation options for UI certificate"
  value       = aws_acm_certificate.ui.domain_validation_options
}

output "nodes_certificate_domain_validation_options" {
  description = "Domain validation options for nodes certificate"  
  value       = aws_acm_certificate.nodes.domain_validation_options
}

# Random subdomain hex (for Cognito domain)
output "subdomain_hex" {
  description = "Hex value of the random subdomain"
  value       = var.random_subdomain ? random_id.subdomain[0].hex : ""
}