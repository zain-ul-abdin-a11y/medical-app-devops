terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Store state remotely (create this S3 bucket first manually)
  backend "s3" {
    bucket = "medical-app-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── VPC ────────────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.app_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true   # set false for HA in production
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Required tags for EKS
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.app_name}-cluster" = "shared"
    "kubernetes.io/role/elb"                        = 1
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${var.app_name}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"               = 1
  }

  tags = var.common_tags
}
