locals {
    env = terraform.workspace
    default_tags = {
        Project     = var.project_name
        Environment = local.env
        Managed_by  = "Terraform"
    }
    name_prefix = "${local.env}-${var.project_name}"
}

# Data sources
data "aws_vpc" "vonq" {
  depends_on = [aws_vpc.vonq]
  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

data "aws_subnets" "app_backend" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vonq.id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["${local.name_prefix}-app-backend-subnet-*"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vonq.id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["${local.name_prefix}-public-subnet-*"]
  }
}

# Secrets
data "aws_secretsmanager_secret_version" "postgres_password" {
  secret_id = aws_secretsmanager_secret.postgres_password.id
  depends_on = [aws_secretsmanager_secret_version.postgres_password]
}

data "aws_secretsmanager_secret_version" "django_secret_key" {
  secret_id = aws_secretsmanager_secret.django_secret_key.id
  depends_on = [aws_secretsmanager_secret_version.django_secret_key]
}