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

# Route53 records for certificate validation (API)
resource "aws_route53_record" "api_cert_validation" {
  count = length(aws_acm_certificate.api.domain_validation_options)
  
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.api.domain_validation_options)[count.index].resource_record_name
  records         = [tolist(aws_acm_certificate.api.domain_validation_options)[count.index].resource_record_value]
  ttl             = 60
  type            = tolist(aws_acm_certificate.api.domain_validation_options)[count.index].resource_record_type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Route53 records for certificate validation (UI)
resource "aws_route53_record" "ui_cert_validation" {
  count = length(aws_acm_certificate.ui.domain_validation_options)
  
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.ui.domain_validation_options)[count.index].resource_record_name
  records         = [tolist(aws_acm_certificate.ui.domain_validation_options)[count.index].resource_record_value]
  ttl             = 60
  type            = tolist(aws_acm_certificate.ui.domain_validation_options)[count.index].resource_record_type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Certificate validation (API)
resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = aws_route53_record.api_cert_validation[*].fqdn
}

# Certificate validation (UI)
resource "aws_acm_certificate_validation" "ui" {
  certificate_arn         = aws_acm_certificate.ui.arn
  validation_record_fqdns = aws_route53_record.ui_cert_validation[*].fqdn
}