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

