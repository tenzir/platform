output "lambda_api_container_repository_url" {
  description = "URL of the Lambda API container repository"
  value       = aws_ecr_repository.lambda_api_container.repository_url
}

output "lambda_ui_container_repository_url" {
  description = "URL of the Lambda UI container repository"
  value       = aws_ecr_repository.lambda_ui_container.repository_url
}

output "lambda_api_container_registry_id" {
  description = "Registry ID of the Lambda API container repository"
  value       = aws_ecr_repository.lambda_api_container.registry_id
}

output "lambda_ui_container_registry_id" {
  description = "Registry ID of the Lambda UI container repository"
  value       = aws_ecr_repository.lambda_ui_container.registry_id
}

output "platform_repository_url" {
  description = "URL of the platform repository"
  value       = aws_ecr_repository.platform.repository_url
}

output "node_repository_url" {
  description = "URL of the node repository"
  value       = aws_ecr_repository.node.repository_url
}