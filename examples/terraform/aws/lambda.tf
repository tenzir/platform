resource "aws_iam_role" "lambda_execution" {
  name = "tenzir-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets_policy" {
  name = "tenzir-lambda-secrets-policy"
  role = aws_iam_role.lambda_execution.id

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
          aws_secretsmanager_secret.tenant_manager_tenant_token_encryption_key.arn,
          aws_secretsmanager_secret.workspace_secrets_master_seed.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_ssm_policy" {
  name = "tenzir-lambda-ssm-policy"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/tenzir/platform/*"
      }
    ]
  })
}


resource "aws_security_group" "lambda" {
  name        = "tenzir-lambda-sg"
  description = "Security group for Tenzir Lambda function"
  vpc_id      = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-lambda-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "lambda_egress" {
  security_group_id = aws_security_group.lambda.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "lambda_dns_udp" {
  security_group_id = aws_security_group.lambda.id
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_lambda_function" "api_function" {
  function_name = "tenzir-api-function"
  role         = aws_iam_role.lambda_execution.arn
  package_type = "Image"
  image_uri    = "${module.bootstrap.lambda_api_container_repository_url}:latest"
  timeout      = 30
  memory_size  = 512

  environment {
    variables = {
      DB_SECRET_ARN                                           = aws_secretsmanager_secret.db_password.arn
      ECS_CLUSTER_ARN                                         = aws_ssm_parameter.ecs_cluster_arn.value
      ECS_TASK_EXECUTION_ROLE_ARN                             = aws_ssm_parameter.ecs_task_execution_role_arn.value
      TENZIR_DEMO_NODE_SECURITY_GROUP_ID                      = aws_ssm_parameter.tenzir_demo_node_security_group_id.value
      TENZIR_DEMO_SUBNET_ID                                   = aws_ssm_parameter.tenzir_demo_subnet_id.value
      STORE__TYPE                                             = "postgres"
      STORE__POSTGRES_URI_SECRET_ARN                          = aws_secretsmanager_secret.postgres_uri.arn
      TENANT_MANAGER_APP_API_KEY_SECRET_ARN                   = aws_secretsmanager_secret.tenant_manager_app_api_key.arn
      TENANT_MANAGER_TENANT_TOKEN_ENCRYPTION_KEY_SECRET_ARN   = aws_secretsmanager_secret.tenant_manager_tenant_token_encryption_key.arn
      WORKSPACE_SECRETS_MASTER_SEED_ARN                       = aws_secretsmanager_secret.workspace_secrets_master_seed.arn
      TENZIR_DEMO_NODE_LOGS_GROUP_NAME                        = aws_ssm_parameter.demo_node_logs_group_name.value
      COGNITO_OIDC_ISSUER_URL                                 = local.oidc_issuer_url
      COGNITO_OAUTH_CLIENT_ID                                 = aws_cognito_user_pool_client.oauth_client.id
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.platform.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy.lambda_ssm_policy
  ]

  lifecycle {
    ignore_changes = [image_uri]
  }
}

resource "aws_lambda_function" "ui_function" {
  function_name = "tenzir-ui-function"
  role         = aws_iam_role.lambda_execution.arn
  package_type = "Image"
  image_uri    = "${module.bootstrap.lambda_ui_container_repository_url}:latest"
  timeout      = 30
  memory_size  = 512

  environment {
    variables = {
      DB_SECRET_ARN = aws_secretsmanager_secret.db_password.arn
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.platform.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc
  ]

  lifecycle {
    ignore_changes = [image_uri]
  }
}

resource "aws_lambda_function_url" "ui_function_url" {
  function_name      = aws_lambda_function.ui_function.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["date", "keep-alive"]
    max_age          = 86400
  }
}

resource "aws_lambda_function_url" "api_function_url" {
  function_name      = aws_lambda_function.api_function.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["date", "keep-alive"]
    max_age          = 86400
  }
}