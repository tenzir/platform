output "ui_lambda_function_url" {
  description = "URL for the UI Lambda function"
  value       = aws_lambda_function_url.ui_function_url.function_url
}