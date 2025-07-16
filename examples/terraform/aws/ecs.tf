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

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tenzir-ecs-service-sg"
  }
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
      name  = "gateway"
      image = "ghcr.io/tenzir/platform:latest"
      
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
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution
  ]
}