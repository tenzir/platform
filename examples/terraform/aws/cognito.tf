resource "aws_cognito_user_pool" "tenzir" {
  name = "tenzir-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Tenzir Account Verification Code"
    email_message        = "Your verification code is {####}"
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  tags = {
    Name = "tenzir-user-pool"
  }
}


# App client for authentication
resource "aws_cognito_user_pool_client" "app_client" {
  name         = "tenzir-app"
  user_pool_id = aws_cognito_user_pool.tenzir.id

  # Enable secret generation for OAuth flows
  generate_secret = true
  
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  
  # Use UI custom domain + /login/oauth/callback as callback URL
  callback_urls = [
    "https://${local.ui_domain}/login/oauth/callback"
  ]
  
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# Data source to get current AWS region
data "aws_region" "current" {}

# Cognito managed domain
resource "aws_cognito_user_pool_domain" "tenzir" {
  domain       = "tenzir-auth-${random_id.subdomain[0].hex}"
  user_pool_id = aws_cognito_user_pool.tenzir.id
}

# Local value to construct the OIDC issuer URL
locals {
  oidc_issuer_url = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.tenzir.id}"
}