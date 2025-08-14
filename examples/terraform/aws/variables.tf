variable "domain_name" {
  description = "The base domain name (e.g., example.org)"
  type        = string
}

variable "random_subdomain" {
  description = "Whether to prepend a random subdomain to the domain name"
  type        = bool
  default     = false
}

variable "amazon_client_id" {
  description = "Amazon Login with Amazon client ID"
  type        = string
}

variable "amazon_client_secret" {
  description = "Amazon Login with Amazon client secret"
  type        = string
  sensitive   = true
}