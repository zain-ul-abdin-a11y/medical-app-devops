variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name prefix for all resources"
  type        = string
  default     = "medical-app"
}

variable "environment" {
  description = "Environment (prod/staging)"
  type        = string
  default     = "prod"
}

variable "db_password" {
  description = "RDS MySQL root password"
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "medical-app"
    ManagedBy   = "terraform"
    Environment = "prod"
  }
}
