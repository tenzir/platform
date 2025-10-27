terraform {
  cloud {
    organization = "tenzir"
    workspaces {
      name = "aws-cloud-edition"
    }
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
  
  assume_role {
    role_arn = var.trusting_role_arn
  }
}