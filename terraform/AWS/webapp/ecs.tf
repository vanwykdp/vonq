# ECS Cluster
resource "aws_ecs_cluster" "vonq" {
  name = "${local.name_prefix}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = local.default_tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 30
  
  tags = local.default_tags
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.name_prefix}-task-execution-role"

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
  
  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Service
resource "aws_ecs_service" "django_app" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.vonq.id
  task_definition = aws_ecs_task_definition.django_app.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = data.aws_subnets.app_backend.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "nginx"
    container_port   = var.nginx_port
  }
  
  depends_on = [aws_lb_listener.http]
  
  tags = local.default_tags
}

# Task Definition
resource "aws_ecs_task_definition" "django_app" {
  family                   = "${local.name_prefix}-django-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  
  container_definitions = jsonencode([
    # Django Application Container
    {
      name      = "django-app"
      image     = "${aws_ecr_repository.django_app.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
            name  = "POSTGRES_USER"
            value = var.postgres_user
        },
        {
            name  = "POSTGRES_DB"
            value = var.postgres_db
        },
        {
            name  = "POSTGRES_HOST"
            value = "localhost"
        },
        {
            name  = "POSTGRES_PORT"
            value = tostring(var.postgres_port)
        },
        {
            name  = "REDIS_URL"
            value = "redis://localhost:${var.redis_port}/0"
        }
      ]

      secrets = [
        {
            name      = "POSTGRES_PASSWORD"
            valueFrom = "${aws_secretsmanager_secret.postgres_password.arn}:password::"
        },
        {
            name      = "DJANGO_SECRET_KEY"
            valueFrom = "${aws_secretsmanager_secret.django_secret_key.arn}:secret_key::"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "django"
        }
      }
    },
    
    # PostgreSQL Container
    {
      name      = "postgres"
      image     = "postgres:13"
      essential = true
      
      portMappings = [
        {
          containerPort = var.postgres_port
          hostPort      = var.postgres_port
          protocol      = "tcp"
        }
      ]
      
      environment = [
        {
          name  = "POSTGRES_DB"
          value = var.postgres_db
        },
        {
          name  = "POSTGRES_USER"
          value = var.postgres_user
        }
      ]

      secrets = [
        {
            name      = "POSTGRES_PASSWORD"
            valueFrom = "${aws_secretsmanager_secret.postgres_password.arn}:password::"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "postgres"
        }
      }
    },
    
    # Redis Container
    {
      name      = "redis"
      image     = "redis:6"
      essential = true
      
      portMappings = [
        {
          containerPort = var.redis_port
          hostPort      = var.redis_port
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "redis"
        }
      }
    },
    
    # Celery Worker Container
    {
      name      = "celery-worker"
      image     = "${aws_ecr_repository.django_app.repository_url}:latest"
      essential = false
      
      command = ["celery", "-A", "project", "worker", "--loglevel=info"]
      
      environment = [
        {
            name  = "POSTGRES_USER"
            value = var.postgres_user
        },
        {
            name  = "POSTGRES_DB"
            value = var.postgres_db
        },
        {
            name  = "POSTGRES_HOST"
            value = "localhost"
        },
        {
            name  = "POSTGRES_PORT"
            value = tostring(var.postgres_port)
        },
        {
            name  = "REDIS_URL"
            value = "redis://localhost:${var.redis_port}/0"
        }
      ]

      secrets = [
        {
            name      = "POSTGRES_PASSWORD"
            valueFrom = "${aws_secretsmanager_secret.postgres_password.arn}:password::"
        },
        {
            name      = "DJANGO_SECRET_KEY"
            valueFrom = "${aws_secretsmanager_secret.django_secret_key.arn}:secret_key::"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "celery"
        }
      }
    },
    
    # Nginx Container
    {
      name      = "nginx"
      image     = "${aws_ecr_repository.nginx.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = var.nginx_port
          hostPort      = var.nginx_port
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx"
        }
      }
    },
    
    # Traefik Container
    {
      name      = "traefik"
      image     = "traefik:v2.5"
      essential = true
      
      portMappings = [
        {
          containerPort = var.traefik_port
          hostPort      = var.traefik_port
          protocol      = "tcp"
        }
      ]
      
      command = [
        "--providers.ecs.region=eu-west-1",
        "--providers.ecs.clusters=${aws_ecs_cluster.vonq.name}",
        "--providers.ecs.exposedByDefault=false",
        "--entryPoints.web.address=:${var.traefik_port}"
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "traefik"
        }
      }
    }
  ])
  
  tags = local.default_tags
}

# ECR Repositories
resource "aws_ecr_repository" "django_app" {
  name                 = "${local.name_prefix}-django-app"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = local.default_tags
}

resource "aws_ecr_repository" "nginx" {
  name                 = "${local.name_prefix}-nginx"
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = local.default_tags
}

# ECR Lifecycle Policies
resource "aws_ecr_lifecycle_policy" "django_app" {
  repository = aws_ecr_repository.django_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "nginx" {
  repository = aws_ecr_repository.nginx.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
