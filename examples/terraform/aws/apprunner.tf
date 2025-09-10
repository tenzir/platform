# App Runner IAM Role for UI Service
resource "aws_iam_role" "apprunner_instance_role" {
  name = "tenzir-apprunner-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "apprunner_secrets_policy" {
  name = "tenzir-apprunner-secrets-policy"
  role = aws_iam_role.apprunner_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_secretsmanager_secret.postgres_uri.arn,
          aws_secretsmanager_secret.tenant_manager_app_api_key.arn,
          aws_secretsmanager_secret.auth_secret.arn,
          aws_secretsmanager_secret.client_secret.arn,
          aws_secretsmanager_secret.user_endpoint.arn,
          aws_secretsmanager_secret.webapp_endpoint.arn
        ]
      }
    ]
  })
}

# App Runner Access Role for ECR
resource "aws_iam_role" "apprunner_access_role" {
  name = "tenzir-apprunner-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_access_role_policy" {
  role       = aws_iam_role.apprunner_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# VPC Connector for App Runner
resource "aws_apprunner_vpc_connector" "ui_connector" {
  vpc_connector_name = "tenzir-ui-vpc-connector"
  subnets            = [aws_subnet.platform.id]
  security_groups    = [aws_security_group.apprunner_ui.id]

  tags = {
    Name = "tenzir-ui-vpc-connector"
  }
}

# Security Group for App Runner
resource "aws_security_group" "apprunner_ui" {
  name        = "tenzir-apprunner-ui-sg"
  description = "Security group for Tenzir App Runner UI service"
  vpc_id      = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-apprunner-ui-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "apprunner_ui_egress" {
  security_group_id = aws_security_group.apprunner_ui.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "apprunner_ui_http" {
  security_group_id = aws_security_group.apprunner_ui.id
  ip_protocol       = "tcp"
  from_port         = 3000
  to_port           = 3000
  cidr_ipv4         = aws_vpc.tenzir.cidr_block
}

# App Runner Service for UI
resource "aws_apprunner_service" "ui" {
  service_name = "tenzir-ui-service"

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_access_role.arn
    }
    image_repository {
      image_configuration {
        port = "3000"
        runtime_environment_variables = {
          # Convert Lambda environment variables to App Runner format
          AUTH_TRUST_HOST                                         = "true"
          PUBLIC_ENABLE_HIGHLIGHT                                 = "false"
          ORIGIN                                                  = "https://${module.bootstrap.ui_domain}"
          PRIVATE_OIDC_PROVIDER_NAME                             = "tenzir"
          PRIVATE_OIDC_PROVIDER_CLIENT_ID                        = local.oidc_client_id
          PRIVATE_OIDC_PROVIDER_ISSUER_URL                       = local.oidc_issuer_url
          PUBLIC_OIDC_PROVIDER_ID                                = var.use_external_oidc ? "external" : "cognito"
          PUBLIC_OIDC_SCOPES                                     = "openid profile email"
          PUBLIC_WEBSOCKET_GATEWAY_ENDPOINT                      = aws_ssm_parameter.gateway_ws_endpoint.value
          PUBLIC_DISABLE_DEMO_NODE_AND_TOUR                      = "false"
        }
        runtime_environment_secrets = {
          # Use secrets for sensitive data
          PRIVATE_OIDC_PROVIDER_CLIENT_SECRET                    = aws_secretsmanager_secret.client_secret.arn
          PRIVATE_USER_ENDPOINT                                  = aws_secretsmanager_secret.user_endpoint.arn
          PRIVATE_WEBAPP_ENDPOINT                                = aws_secretsmanager_secret.webapp_endpoint.arn
          PRIVATE_WEBAPP_KEY                                     = aws_secretsmanager_secret.tenant_manager_app_api_key.arn
          AUTH_SECRET                                            = aws_secretsmanager_secret.auth_secret.arn
          PRIVATE_DRIZZLE_DATABASE_URL                           = aws_secretsmanager_secret.postgres_uri.arn
        }
      }
      image_identifier      = "${module.bootstrap.ui_repository_url}:latest"
      image_repository_type = "ECR"
    }
    auto_deployments_enabled = false
  }

  instance_configuration {
    cpu               = "0.25 vCPU"
    memory            = "0.5 GB"
    instance_role_arn = aws_iam_role.apprunner_instance_role.arn
  }

  network_configuration {
    ingress_configuration {
      is_publicly_accessible = true
    }
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.ui_connector.arn
    }
  }

  tags = {
    Name = "tenzir-ui-apprunner"
  }

  depends_on = [
    aws_iam_role_policy.apprunner_secrets_policy,
    aws_iam_role_policy_attachment.apprunner_access_role_policy,
    aws_vpc_security_group_ingress_rule.rds_postgres_apprunner,
    # Ensure all secrets and their versions exist before creating the service
    aws_secretsmanager_secret_version.client_secret,
    aws_secretsmanager_secret_version.user_endpoint,
    aws_secretsmanager_secret_version.webapp_endpoint,
    aws_secretsmanager_secret_version.db_password,
    aws_secretsmanager_secret_version.postgres_uri,
    aws_secretsmanager_secret_version.tenant_manager_app_api_key,
    aws_secretsmanager_secret_version.auth_secret
  ]
}

# Create secrets for App Runner service endpoints
resource "aws_secretsmanager_secret" "client_secret" {
  name                    = "tenzir/apprunner/ui/client-secret-${module.bootstrap.subdomain_hex}"
  description             = "OIDC Client Secret for App Runner UI"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "client_secret" {
  secret_id     = aws_secretsmanager_secret.client_secret.id
  secret_string = local.oidc_client_secret
}

resource "aws_secretsmanager_secret" "user_endpoint" {
  name                    = "tenzir/apprunner/ui/user-endpoint-${module.bootstrap.subdomain_hex}"
  description             = "User Endpoint for App Runner UI"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "user_endpoint" {
  secret_id     = aws_secretsmanager_secret.user_endpoint.id
  secret_string = "${aws_lambda_function_url.api_function_url.function_url}user"
}

resource "aws_secretsmanager_secret" "webapp_endpoint" {
  name                    = "tenzir/apprunner/ui/webapp-endpoint-${module.bootstrap.subdomain_hex}"
  description             = "Webapp Endpoint for App Runner UI"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "webapp_endpoint" {
  secret_id     = aws_secretsmanager_secret.webapp_endpoint.id
  secret_string = "${aws_lambda_function_url.api_function_url.function_url}webapp"
}

# Custom domain for App Runner
resource "aws_apprunner_custom_domain_association" "ui" {
  domain_name = module.bootstrap.ui_domain
  service_arn = aws_apprunner_service.ui.arn

  depends_on = [aws_acm_certificate_validation.ui]
}

# Route53 records for App Runner domain validation
# Using tolist() workaround to handle unknown values in certificate_validation_records
# See: https://github.com/hashicorp/terraform-provider-aws/issues/23460
locals {
  validation_records = tolist(aws_apprunner_custom_domain_association.ui.certificate_validation_records)
}

resource "aws_route53_record" "ui_apprunner_validation" {
  count = length(local.validation_records)
  
  allow_overwrite = true
  name            = local.validation_records[count.index].name
  records         = [local.validation_records[count.index].value]
  ttl             = 60
  type            = local.validation_records[count.index].type
  zone_id         = module.bootstrap.route53_zone_id
}

# Update Route53 record to point to App Runner
resource "aws_route53_record" "ui_apprunner" {
  zone_id = module.bootstrap.route53_zone_id
  name    = module.bootstrap.ui_domain
  type    = "CNAME"
  ttl     = 300
  records = [aws_apprunner_custom_domain_association.ui.dns_target]

  depends_on = [
    aws_apprunner_custom_domain_association.ui
  ]
}