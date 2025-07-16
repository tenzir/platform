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
        Resource = aws_secretsmanager_secret.db_password.arn
      }
    ]
  })
}

resource "aws_ecr_repository" "lambda_container" {
  name = "tenzir-lambda-container"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "lambda_ui_container" {
  name = "tenzir-lambda-ui-container"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_security_group" "lambda" {
  name        = "tenzir-lambda-sg"
  description = "Security group for Tenzir Lambda function"
  vpc_id      = aws_vpc.tenzir.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tenzir-lambda-sg"
  }
}

resource "aws_lambda_function" "tenzir_function" {
  function_name = "tenzir-container-function"
  role         = aws_iam_role.lambda_execution.arn
  package_type = "Image"
  image_uri    = "${aws_ecr_repository.lambda_container.repository_url}:latest"
  timeout      = 30
  memory_size  = 512

  vpc_config {
    subnet_ids         = [aws_subnet.platform.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc
  ]
}

resource "aws_lambda_function" "ui_function" {
  function_name = "tenzir-ui-function"
  role         = aws_iam_role.lambda_execution.arn
  package_type = "Image"
  image_uri    = "${aws_ecr_repository.lambda_ui_container.repository_url}:latest"
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