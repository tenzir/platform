resource "aws_ecr_repository" "node" {
  name = "tenzir-sovereign-platform/node"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# New unified ECR repositories
resource "aws_ecr_repository" "platform_api" {
  name = "tenzir-sovereign-platform/platform-api"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "gateway" {
  name = "tenzir-sovereign-platform/gateway"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "ui" {
  name = "tenzir-sovereign-platform/ui"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}