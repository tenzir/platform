variable "tenzir_platform_version" {
  description = "The version tag for Tenzir platform images (e.g., 'latest')"
  type        = string
  default     = "latest"
}

variable "tenzir_platform_domain" {
  description = "The public domain for the Tenzir platform"
  type        = string
}

variable "tenzir_platform_control_endpoint" {
  description = "The public websocket gateway endpoint"
  type        = string
}

variable "tenzir_platform_api_endpoint" {
  description = "The public API endpoint for the Tenzir platform"
  type        = string
}

variable "tenzir_platform_blobs_endpoint" {
  description = "The public endpoint for blob storage"
  type        = string
}

variable "tenzir_platform_demo_node_image" {
  description = "Image for Tenzir demo nodes"
  type        = string
  default     = "tenzir/tenzir-demo:latest"
}

variable "tenzir_platform_store_type" {
  description = "The store type for Tenzir platform (e.g., 'postgres')"
  type        = string
  default     = "postgres"
}

variable "tenzir_platform_internal_bucket_name" {
  description = "Internal bucket name for blob storage"
  type        = string
  default     = "tenzir-platform-bucket"
}

variable "tenzir_platform_postgres_db" {
  description = "PostgreSQL database name"
  type        = string
}

variable "tenzir_platform_postgres_user" {
  description = "PostgreSQL username"
  type        = string
}

variable "blob_storage_access_key_id" {
  description = "Access key ID for blob storage"
  type        = string
}

# Sensitive variables - these should be provided securely (e.g., via .tfvars file not committed to VCS, or environment variables)

variable "private_oidc_provider_client_secret" {
  description = "Client secret for OIDC provider"
  type        = string
  sensitive   = true
}

variable "tenzir_platform_internal_app_api_key" {
  description = "Internal API key for the app"
  type        = string
  sensitive   = true
}

variable "tenzir_platform_internal_auth_secret" {
  description = "Internal authentication secret"
  type        = string
  sensitive   = true
}

variable "tenzir_platform_postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "tenant_manager_tenant_token_encryption_key" {
  description = "Encryption key for tenant tokens"
  type        = string
  sensitive   = true
}

variable "blob_storage_secret_access_key" {
  description = "Secret access key for blob storage"
  type        = string
  sensitive   = true
}