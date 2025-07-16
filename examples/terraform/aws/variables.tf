variable "domain_name" {
  description = "The base domain name (e.g., example.org)"
  type        = string
}

variable "random_subdomain" {
  description = "Whether to prepend a random subdomain to the domain name"
  type        = bool
  default     = false
}

variable "trusting_role_arn" {
  description = "The ARN of the trusting role to assume for AWS operations"
  type        = string
}



# OIDC Configuration Variables (optional)
variable "use_external_oidc" {
  description = "Whether to use an external OIDC provider instead of AWS Cognito"
  type        = bool
  default     = false
}

variable "external_oidc_issuer_url" {
  description = "The issuer URL for external OIDC provider (required when use_external_oidc is true)"
  type        = string
  default     = ""
}

variable "external_oidc_client_id" {
  description = "The client ID for external OIDC provider (required when use_external_oidc is true)"
  type        = string
  default     = ""
}

variable "external_oidc_client_secret" {
  description = "The client secret for external OIDC provider (required when use_external_oidc is true)"
  type        = string
  default     = ""
  sensitive   = true
}

# Input validation
locals {
  external_oidc_validation = (
    var.use_external_oidc && (
      var.external_oidc_issuer_url == "" ||
      var.external_oidc_client_id == "" ||
      var.external_oidc_client_secret == ""
    )
  ) ? tobool("External OIDC is enabled but required variables are missing. Please provide external_oidc_issuer_url, external_oidc_client_id, and external_oidc_client_secret.") : true
}


# Additional environment variables for API service (optional)
variable "api_service_extra_environment_variables" {
  description = "Additional environment variables for the API ECS service"
  type        = map(string)
  default     = {}
}