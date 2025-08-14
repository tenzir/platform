output "node_repository_url" {
  description = "URL of the node repository"
  value       = aws_ecr_repository.node.repository_url
}

# New unified repository outputs
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