resource "aws_security_group" "alb" {
  name        = "tenzir-alb-sg"
  description = "Security group for Tenzir Application Load Balancer"
  vpc_id      = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_lb" "gateway" {
  name               = "tenzir-gateway-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.nodes.id]

  enable_deletion_protection = false

  tags = {
    Name = "tenzir-gateway-alb"
  }
}

resource "aws_lb_target_group" "gateway" {
  name        = "tenzir-gateway-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.tenzir.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "tenzir-gateway-tg"
  }
}

# Create root CA private key
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create root CA certificate
resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name         = "Tenzir Root CA"
    organization        = "Tenzir"
    organizational_unit = "Infrastructure"
    country             = "US"
    locality           = "San Francisco"
    province           = "CA"
  }

  validity_period_hours = 17520 # 2 years
  is_ca_certificate     = true

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "crl_signing",
  ]
}

# Create server private key
resource "tls_private_key" "gateway" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create certificate signing request for server
resource "tls_cert_request" "gateway" {
  private_key_pem = tls_private_key.gateway.private_key_pem

  subject {
    common_name  = "*.elb.amazonaws.com"
    organization = "Tenzir"
  }

  dns_names = [
    "*.elb.amazonaws.com",
    "*.eu-west-1.elb.amazonaws.com"
  ]
}

# Sign the server certificate with CA
resource "tls_locally_signed_cert" "gateway" {
  cert_request_pem   = tls_cert_request.gateway.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Upload the CA-signed certificate to ACM
resource "aws_acm_certificate" "gateway" {
  private_key       = tls_private_key.gateway.private_key_pem
  certificate_body  = tls_locally_signed_cert.gateway.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem

  tags = {
    Name = "tenzir-gateway-ca-signed-cert"
  }
}

resource "aws_lb_listener" "gateway_https" {
  load_balancer_arn = aws_lb.gateway.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.gateway.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }
}

# Redirect HTTP to HTTPS
resource "aws_lb_listener" "gateway_http_redirect" {
  load_balancer_arn = aws_lb.gateway.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}