# Outputs
output "load_balancer_dns" {
  value       = aws_lb.vonq.dns_name
  description = "The DNS name of the load balancer"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.vonq.name
  description = "The name of the ECS cluster"
}

output "django_ecr_repository_url" {
  value       = aws_ecr_repository.django_app.repository_url
  description = "The URL of the Django ECR repository"
}

output "nginx_ecr_repository_url" {
  value       = aws_ecr_repository.nginx.repository_url
  description = "The URL of the Nginx ECR repository"
}

output "route53_zone_id" {
  value       = var.primary_region ? aws_route53_zone.vonq[0].zone_id : null
  description = "Route53 hosted zone ID"
}