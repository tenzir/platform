resource "aws_cognito_user_pool" "tenzir" {
  name = "tenzir-user-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  
  # Disable self-signup
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

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
  
  # Enable identity providers
  supported_identity_providers = ["COGNITO"]
  
  # Use UI custom domain + /login/oauth/callback as callback URL
  callback_urls = [
    "https://${local.ui_domain}/login/oauth/callback"
  ]
  
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true
  
  # Disable SRP auth flows (OAuth only)
  explicit_auth_flows = ["ALLOW_REFRESH_TOKEN_AUTH"]
  
  # Enable refresh token rotation
  auth_session_validity = 3
  
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

# UI customization for the hosted login page
resource "aws_cognito_user_pool_ui_customization" "tenzir" {
  user_pool_id = aws_cognito_user_pool_domain.tenzir.user_pool_id
  client_id    = aws_cognito_user_pool_client.app_client.id
  
  # CSS customization for login page
  css = <<-EOF
    .banner-customizable {
      padding: 25px 0px 25px 0px;
      background-color: #2d3142;
    }
    .label-customizable {
      font-weight: 400;
    }
    .textDescription-customizable {
      padding-top: 10px;
      padding-bottom: 10px;
      display: block;
      font-size: 16px;
    }
    .idpDescription-customizable {
      padding-top: 10px;
      padding-bottom: 10px;
      display: block;
      font-size: 16px;
    }
    .legalText-customizable {
      color: #747474;
      font-size: 11px;
    }
    .submitButton-customizable {
      font-size: 14px;
      font-weight: bold;
      margin: 20px 0px 10px 0px;
      height: 40px;
      width: 100%;
      color: #fff;
      background-color: #4889f4;
    }
    .submitButton-customizable:hover {
      color: #fff;
      background-color: #3d71d9;
    }
    .errorMessage-customizable {
      padding: 5px;
      font-size: 14px;
      width: 100%;
      background: #F5F5F5;
      border: 2px solid #D64958;
      color: #D64958;
    }
    .inputField-customizable {
      height: 34px;
      width: 100%;
      color: #555;
      background-color: #fff;
      border: 1px solid #ccc;
    }
    .inputField-customizable:focus {
      border-color: #66afe9;
      outline: 0;
    }
    .idpButton-customizable {
      height: 40px;
      width: 100%;
      text-align: center;
      margin-bottom: 15px;
      color: #fff;
      background-color: #5bc0de;
      border-color: #46b8da;
    }
    .idpButton-customizable:hover {
      color: #fff;
      background-color: #31b0d5;
      border-color: #269abc;
    }
  EOF
}

# Generate random password for admin user
resource "random_password" "admin_password" {
  length  = 24
  special = true
}

# Store admin password in Secrets Manager
resource "aws_secretsmanager_secret" "admin_password" {
  name                    = "tenzir/cognito/admin-password"
  description             = "Admin user password for Tenzir Cognito user pool"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "admin_password" {
  secret_id     = aws_secretsmanager_secret.admin_password.id
  secret_string = random_password.admin_password.result
}

# Create default admin user
resource "aws_cognito_user" "admin" {
  user_pool_id = aws_cognito_user_pool.tenzir.id
  username     = "admin@${local.base_domain}"
  
  attributes = {
    email          = "admin@${local.base_domain}"
    email_verified = true
  }
  
  password = random_password.admin_password.result
  
  message_action = "SUPPRESS"
}

# Local value to construct the OIDC issuer URL
locals {
  oidc_issuer_url = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.tenzir.id}"
}