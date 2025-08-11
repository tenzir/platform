# CA Certificate secret for Lambda container
resource "aws_secretsmanager_secret" "tenzir_ca_certificate" {
  name        = "tenzir-ca-certificate"
  description = "Tenzir Root CA certificate for Lambda container SSL verification"
}

resource "aws_secretsmanager_secret_version" "tenzir_ca_certificate" {
  secret_id     = aws_secretsmanager_secret.tenzir_ca_certificate.id
  secret_string = tls_self_signed_cert.ca.cert_pem
}