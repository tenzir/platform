resource "aws_iam_role" "ecr_pull_through_cache" {
  name = "tenzir-ecr-pull-through-cache-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ecr.amazonaws.com",
            "pullthroughcache.ecr.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_pull_through_cache" {
  name = "tenzir-ecr-pull-through-cache-policy"
  role = aws_iam_role.ecr_pull_through_cache.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_ecr_pull_through_cache_rule" "marketplace" {
  ecr_repository_prefix = "marketplace"
  upstream_registry_url = "709825985650.dkr.ecr.us-east-1.amazonaws.com"
  custom_role_arn       = aws_iam_role.ecr_pull_through_cache.arn
}

resource "aws_ecs_cluster" "platform" {
  name = "tenzir-platform"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "tenzir-platform"
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "tenzir-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


resource "aws_security_group" "ecs_service" {
  name        = "tenzir-ecs-service-sg"
  description = "Security group for Tenzir ECS service"
  vpc_id      = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-ecs-service-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_service_http" {
  security_group_id = aws_security_group.ecs_service.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_service_https" {
  security_group_id = aws_security_group.ecs_service.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ecs_service_egress" {
  security_group_id = aws_security_group.ecs_service.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "ecs_api" {
  name        = "tenzir-ecs-api-sg"
  description = "Security group for Tenzir ECS API service"
  vpc_id      = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-ecs-api-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_api_http" {
  security_group_id = aws_security_group.ecs_api.id
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_service_alb" {
  security_group_id            = aws_security_group.ecs_service.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_api_egress" {
  security_group_id = aws_security_group.ecs_api.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "ecs_node" {
  name        = "tenzir-ecs-node-sg"
  description = "Security group for Tenzir ECS node service"
  vpc_id      = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-ecs-node-sg"
  }
}

resource "aws_security_group" "ecs_demo_node" {
  name        = "tenzir-ecs-demo-node-sg"
  description = "Security group for Tenzir ECS demo node service"
  vpc_id      = aws_vpc.tenzir.id

  tags = {
    Name = "tenzir-ecs-demo-node-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "ecs_node_egress" {
  security_group_id = aws_security_group.ecs_node.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ecs_demo_node_egress" {
  security_group_id = aws_security_group.ecs_demo_node.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_ecs_task_definition" "gateway" {
  family                   = "tenzir-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name    = "gateway"
      image   = "${module.bootstrap.platform_repository_url}:latest"
      command = ["tenant_manager/ws/server/local.py"]
      
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/tenzir-gateway"
          "awslogs-region"        = "eu-west-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      essential = true
    }
  ])
}

resource "aws_cloudwatch_log_group" "gateway" {
  name              = "/ecs/tenzir-gateway"
  retention_in_days = 7
}

resource "aws_ecs_service" "gateway" {
  name            = "gateway"
  cluster         = aws_ecs_cluster.platform.id
  task_definition = aws_ecs_task_definition.gateway.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.platform.id]
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gateway.arn
    container_name   = "gateway"
    container_port   = 80
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution,
    aws_lb_listener.gateway_https
  ]
}

resource "aws_ecs_task_definition" "api" {
  family                   = "tenzir-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "api"
      image = "${module.bootstrap.lambda_api_container_repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "RUN_MODE"
          value = "ECS"
        },
        {
          name  = "DB_SECRET_ARN"
          value = aws_secretsmanager_secret.db_password.arn
        },
        {
          name  = "TENZIR_DEMO_NODE_LOGS_GROUP_NAME"
          value = aws_ssm_parameter.demo_node_logs_group_name.value
        },
        {
          name  = "STORE__TYPE"
          value = "postgres"
        },
        {
          name  = "STORE__POSTGRES_URI_SECRET_ARN"
          value = aws_secretsmanager_secret.postgres_uri.arn
        },
        {
          name  = "TENANT_MANAGER_APP_API_KEY_SECRET_ARN"
          value = aws_secretsmanager_secret.tenant_manager_app_api_key.arn
        },
        {
          name  = "TENANT_MANAGER_TENANT_TOKEN_ENCRYPTION_KEY_SECRET_ARN"
          value = aws_secretsmanager_secret.tenant_manager_tenant_token_encryption_key.arn
        },
        {
          name  = "WORKSPACE_SECRETS_MASTER_SEED_ARN"
          value = aws_secretsmanager_secret.workspace_secrets_master_seed.arn
        },
        {
          name  = "BASE_PATH"
          value = ""
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/tenzir-api"
          "awslogs-region"        = "eu-west-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      essential = true
    }
  ])
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/tenzir-api"
  retention_in_days = 7
}

resource "aws_iam_role" "ecs_task_role" {
  name = "tenzir-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_secrets" {
  name = "tenzir-ecs-task-secrets-policy"
  role = aws_iam_role.ecs_task_role.id

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

resource "aws_ecs_service" "api" {
  name            = "api"
  cluster         = aws_ecs_cluster.platform.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.platform.id]
    security_groups  = [aws_security_group.ecs_api.id]
    assign_public_ip = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution,
    aws_iam_role_policy.ecs_task_secrets
  ]
}

resource "aws_ecs_task_definition" "node" {
  family                   = "tenzir-node"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name  = "node"
      image = "709825985650.dkr.ecr.us-east-1.amazonaws.com/tenzir/tenzir-node:v5.8.0"
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/tenzir-node"
          "awslogs-region"        = "eu-west-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      essential = true
    }
  ])
}

resource "aws_cloudwatch_log_group" "node" {
  name              = "/ecs/tenzir-node"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "demo_node" {
  name              = "/ecs/tenzir-demo-node"
  retention_in_days = 7
}

resource "aws_ssm_parameter" "demo_node_logs_group_name" {
  name  = "/tenzir/platform/demo-node-logs-group-name"
  type  = "String"
  value = aws_cloudwatch_log_group.demo_node.name
}

resource "aws_ssm_parameter" "ecs_cluster_arn" {
  name  = "/tenzir/platform/ecs-cluster-arn"
  type  = "String"
  value = aws_ecs_cluster.platform.arn
}

resource "aws_ssm_parameter" "ecs_task_execution_role_arn" {
  name  = "/tenzir/platform/ecs-task-execution-role-arn"
  type  = "String"
  value = aws_iam_role.ecs_task_execution.arn
}

resource "aws_ssm_parameter" "tenzir_demo_node_security_group_id" {
  name  = "/tenzir/platform/tenzir-demo-node-security-group-id"
  type  = "String"
  value = aws_security_group.ecs_demo_node.id
}

resource "aws_ssm_parameter" "tenzir_demo_subnet_id" {
  name  = "/tenzir/platform/tenzir-demo-subnet-id"
  type  = "String"
  value = aws_subnet.nodes.id
}

resource "aws_ssm_parameter" "gateway_ws_endpoint" {
  name  = "/tenzir/platform/gateway-ws-endpoint"
  type  = "String"
  value = "wss://${aws_lb.gateway.dns_name}"
}

resource "aws_ssm_parameter" "gateway_http_endpoint" {
  name  = "/tenzir/platform/gateway-http-endpoint"
  type  = "String"
  value = "https://${aws_lb.gateway.dns_name}"
}

resource "aws_ecs_service" "node" {
  name            = "node"
  cluster         = aws_ecs_cluster.platform.id
  task_definition = aws_ecs_task_definition.node.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.nodes.id]
    security_groups  = [aws_security_group.ecs_node.id]
    assign_public_ip = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution
  ]
}

