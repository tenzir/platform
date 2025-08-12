locals {
  # Generate random subdomain if requested
  random_prefix = var.random_subdomain ? "${random_id.subdomain[0].hex}." : ""
  
  # Construct the base domain
  base_domain = "${local.random_prefix}${var.domain_name}"
  
  # API and UI domain names
  api_domain = "api.${local.base_domain}"
  ui_domain  = "ui.${local.base_domain}"
}

# Random ID for subdomain (only created if random_subdomain is true)
resource "random_id" "subdomain" {
  count       = var.random_subdomain ? 1 : 0
  byte_length = 3
}