# ecs.tf - ECS Cluster with Fargate launch type for Django application

# Variables
variable "project_name" {
  type        = string
  description = "Prefix used in global naming convention"
  default     = "vonq"
}

variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "eu-west-1"
}

variable "vpc_cidr_block" {
    type = string
    description = "Network CIDR for VPC"
}

variable "app_port" {
  type        = number
  description = "Port on which the application runs"
  default     = 8000
}

variable "nginx_port" {
  type        = number
  description = "Port on which Nginx runs"
  default     = 80
}

variable "traefik_port" {
  type        = number
  description = "Port on which Traefik runs"
  default     = 8080
}

variable "redis_port" {
  type        = number
  description = "Port on which Redis runs"
  default     = 6379
}

variable "postgres_port" {
  type        = number
  description = "Port on which PostgreSQL runs"
  default     = 5432
}

variable "postgres_db" {
  type        = string
  description = "PostgreSQL database name"
  default     = "django_db"
}

variable "postgres_user" {
  type        = string
  description = "PostgreSQL username"
  default     = "django_user"
}

# Variables for Route53
variable "domain_name" {
  type        = string
  description = "Domain name for the application"
  default     = "darryl-vonq.com"
}

variable "primary_region" {
  type        = bool
  description = "Whether this is the primary region deployment"
  default     = true
}