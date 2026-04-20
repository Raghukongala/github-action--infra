terraform {
  required_version = ">= 1.5.0"
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
  backend "s3" {
    bucket         = "ramama123"
    key            = "eks/ecommerce/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "raghuterraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
