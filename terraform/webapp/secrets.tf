# Secrets Manager
resource "aws_secretsmanager_secret" "postgres_password" {
  name = "${local.name_prefix}/postgres/password"
  
  tags = local.default_tags
}

resource "aws_secretsmanager_secret_version" "postgres_password" {
  secret_id = aws_secretsmanager_secret.postgres_password.id
  secret_string = jsonencode({
    password = random_password.postgres.result
  })
}

resource "aws_secretsmanager_secret" "django_secret_key" {
  name = "${local.name_prefix}/django/secret-key"
  
  tags = local.default_tags
}

resource "aws_secretsmanager_secret_version" "django_secret_key" {
  secret_id = aws_secretsmanager_secret.django_secret_key.id
  secret_string = jsonencode({
    secret_key = random_password.django_secret.result
  })
}

# Random passwords
resource "random_password" "postgres" {
  length  = 16
  special = true
}

resource "random_password" "django_secret" {
  length  = 50
  special = true
}

resource "aws_iam_role_policy" "secrets_policy" {
  name = "${local.name_prefix}-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.postgres_password.arn,
          aws_secretsmanager_secret.django_secret_key.arn
        ]
      }
    ]
  })
}
