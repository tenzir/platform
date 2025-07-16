# Route53 records for certificate validation (API)
resource "aws_route53_record" "api_cert_validation" {
  for_each = {
    for dvo in module.bootstrap.api_certificate_domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = module.bootstrap.route53_zone_id
}

# Route53 records for certificate validation (UI)
resource "aws_route53_record" "ui_cert_validation" {
  for_each = {
    for dvo in module.bootstrap.ui_certificate_domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = module.bootstrap.route53_zone_id
}

# Route53 records for certificate validation (Nodes)
resource "aws_route53_record" "nodes_cert_validation" {
  for_each = {
    for dvo in module.bootstrap.nodes_certificate_domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = module.bootstrap.route53_zone_id
}

# Certificate validation (API)
resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = module.bootstrap.api_certificate_arn
  validation_record_fqdns = [for record in aws_route53_record.api_cert_validation : record.fqdn]
}

# Certificate validation (UI)
resource "aws_acm_certificate_validation" "ui" {
  certificate_arn         = module.bootstrap.ui_certificate_arn
  validation_record_fqdns = [for record in aws_route53_record.ui_cert_validation : record.fqdn]
}

# Certificate validation (Nodes)
resource "aws_acm_certificate_validation" "nodes" {
  certificate_arn         = module.bootstrap.nodes_certificate_arn
  validation_record_fqdns = [for record in aws_route53_record.nodes_cert_validation : record.fqdn]
}