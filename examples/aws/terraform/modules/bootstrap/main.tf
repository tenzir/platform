resource "aws_ecr_repository" "node" {
  name = "tenzir-sovereign-platform/node"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# New unified ECR repositories
resource "aws_ecr_repository" "platform_api" {
  name = "tenzir-sovereign-platform/platform-api"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "gateway" {
  name = "tenzir-sovereign-platform/gateway"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "ui" {
  name = "tenzir-sovereign-platform/ui"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Domain configuration
locals {
  # Generate tenant subdomain if requested
  tenant_subdomain = var.random_subdomain ? "tenant-${random_id.subdomain[0].hex}" : ""
  
  # Construct the base domain with tenant prefix
  base_domain = var.random_subdomain ? "${local.tenant_subdomain}.${var.domain_name}" : var.domain_name
  
  # API, UI, and Nodes domain names
  api_domain   = "api.${local.base_domain}"
  ui_domain    = "ui.${local.base_domain}"
  nodes_domain = "nodes.${local.base_domain}"
}

# Random ID for subdomain (only created if random_subdomain is true)
resource "random_id" "subdomain" {
  count       = var.random_subdomain ? 1 : 0
  byte_length = 3
}

# Data source for existing Route53 hosted zone
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# ACM Certificate for API subdomain
resource "aws_acm_certificate" "api" {
  domain_name       = local.api_domain
  validation_method = "DNS"

  tags = {
    Name = "tenzir-api-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ACM Certificate for UI subdomain
resource "aws_acm_certificate" "ui" {
  domain_name       = local.ui_domain
  validation_method = "DNS"

  tags = {
    Name = "tenzir-ui-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ACM Certificate for Nodes subdomain
resource "aws_acm_certificate" "nodes" {
  domain_name       = local.nodes_domain
  validation_method = "DNS"

  tags = {
    Name = "tenzir-nodes-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

