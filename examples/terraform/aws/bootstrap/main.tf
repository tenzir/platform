resource "aws_ecr_repository" "lambda_api_container" {
  name = "tenzir-lambda-api-container"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "lambda_ui_container" {
  name = "tenzir-ui-container"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "platform" {
  name = "tenzir/gateway"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "node" {
  name = "tenzir-sovereign-platform/node"
  force_delete = true
  
  image_scanning_configuration {
    scan_on_push = true
  }
}