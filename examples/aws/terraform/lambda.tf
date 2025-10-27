# API Lambda IAM Role
resource "aws_iam_role" "api_lambda_execution" {
  name = "tenzir-api-lambda-execution-role"

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

resource "aws_iam_role_policy_attachment" "api_lambda_basic" {
  role       = aws_iam_role.api_lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "api_lambda_vpc" {
  role       = aws_iam_role.api_lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "api_lambda_secrets_policy" {
  name = "tenzir-api-lambda-secrets-policy"
  role = aws_iam_role.api_lambda_execution.id

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
          aws_secretsmanager_secret.workspace_secrets_master_seed.arn,
          aws_secretsmanager_secret.auth_secret.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_lambda_ssm_policy" {
  name = "tenzir-api-lambda-ssm-policy"
  role = aws_iam_role.api_lambda_execution.id

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

resource "aws_iam_role_policy" "api_lambda_s3_policy" {
  name = "tenzir-api-lambda-s3-policy"
  role = aws_iam_role.api_lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.tenzir_sidepath.arn,
          "${aws_s3_bucket.tenzir_sidepath.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_lambda_cloudformation_policy" {
  name = "tenzir-api-lambda-cloudformation-policy"
  role = aws_iam_role.api_lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackEvents",
          "cloudformation:DescribeStackResources",
          "cloudformation:GetStackPolicy",
          "cloudformation:GetTemplate",
          "cloudformation:ListStackResources",
          "cloudformation:ListStacks",
          "cloudformation:ValidateTemplate"
        ]
        Resource = "arn:aws:cloudformation:*:*:stack/demo-*/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_lambda_ecs_policy" {
  name = "tenzir-api-lambda-ecs-policy"
  role = aws_iam_role.api_lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:DescribeServices"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "ecs:cluster" = aws_ssm_parameter.ecs_cluster_arn.value
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:ListTaskDefinitions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_ssm_parameter.ecs_task_execution_role_arn.value
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
  role         = aws_iam_role.api_lambda_execution.arn
  package_type = "Image"
  image_uri    = "${module.bootstrap.platform_api_repository_url}:latest"
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
      TENANT_MANAGER_AUTH__TRUSTED_AUDIENCES                 = jsonencode({
        "issuer": "${local.oidc_issuer_url}",
        "audiences": ["${local.oidc_client_id}"],
      })
      TENANT_MANAGER_AUTH__ADMIN_FUNCTIONS                 = jsonencode(var.use_external_oidc ? [] : [{
        "auth_fn": "auth_user",
        "user_id": aws_cognito_user.admin[0].sub
      }])
      BASE_PATH                                               = ""
      TENANT_MANAGER_SIDEPATH_BUCKET_NAME                     = aws_s3_bucket.tenzir_sidepath.bucket
      TENZIR_DEMO_NODE_IMAGE                                  = "${module.bootstrap.node_repository_url}:latest"
      GATEWAY_WS_ENDPOINT                                     = aws_ssm_parameter.gateway_ws_endpoint.value
      GATEWAY_HTTP_ENDPOINT                                   = aws_ssm_parameter.gateway_http_endpoint.value
    }
  }


  vpc_config {
    subnet_ids         = [aws_subnet.platform.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.api_lambda_basic,
    aws_iam_role_policy_attachment.api_lambda_vpc,
    aws_iam_role_policy.api_lambda_secrets_policy,
    aws_iam_role_policy.api_lambda_ssm_policy,
    aws_iam_role_policy.api_lambda_s3_policy,
    aws_iam_role_policy.api_lambda_cloudformation_policy,
    aws_iam_role_policy.api_lambda_ecs_policy,
  ]

  lifecycle {
    ignore_changes = [image_uri]
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


# API Gateway for API Lambda
resource "aws_apigatewayv2_api" "api_api" {
  name          = "tenzir-api-api"
  protocol_type = "HTTP"
  description   = "API Gateway for Tenzir API Lambda"

  cors_configuration {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age          = 86400
  }
}

resource "aws_apigatewayv2_integration" "api_lambda" {
  api_id             = aws_apigatewayv2_api.api_api.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.api_function.invoke_arn

  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "api_default" {
  api_id    = aws_apigatewayv2_api.api_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_stage" "api_default" {
  api_id      = aws_apigatewayv2_api.api_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api_api.execution_arn}/*/*"
}

# Custom domain for API API Gateway
resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = module.bootstrap.api_domain

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.api.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "api" {
  api_id      = aws_apigatewayv2_api.api_api.id
  domain_name = aws_apigatewayv2_domain_name.api.id
  stage       = aws_apigatewayv2_stage.api_default.id
}

# Route53 record for API domain
resource "aws_route53_record" "api" {
  zone_id = module.bootstrap.route53_zone_id
  name    = module.bootstrap.api_domain
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_apigatewayv2_domain_name.api]
}