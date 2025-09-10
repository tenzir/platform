variable "domain_name" {
  description = "The base domain name (e.g., example.org)"
  type        = string
}

variable "random_subdomain" {
  description = "Whether to prepend a random subdomain to the domain name"
  type        = bool
  default     = false
}