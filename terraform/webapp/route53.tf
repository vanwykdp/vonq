# Route53 Hosted Zone (only in primary region)
resource "aws_route53_zone" "vonq" {
  count = var.primary_region ? 1 : 0
  name  = var.domain_name
  tags  = local.default_tags
}

# Data source for hosted zone (secondary region)
data "aws_route53_zone" "vonq" {
  count = var.primary_region ? 0 : 1
  name  = var.domain_name
}

locals {
  zone_id = var.primary_region ? aws_route53_zone.vonq[0].zone_id : data.aws_route53_zone.vonq[0].zone_id
}

# Health Check
resource "aws_route53_health_check" "alb_health" {
  fqdn                            = aws_lb.vonq.dns_name
  port                            = 80
  type                            = "HTTP"
  resource_path                   = "/"
  failure_threshold               = 3
  request_interval                = 30
  cloudwatch_alarm_region         = var.aws_region

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}-health-check"
  })
}

# Primary region records - use subdomain for geolocation
resource "aws_route53_record" "primary_geo" {
  count   = var.primary_region ? 1 : 0
  zone_id = local.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  set_identifier = "primary-eu"
  
  geolocation_routing_policy {
    continent = "EU"
  }

  health_check_id = aws_route53_health_check.alb_health.id

  alias {
    name                   = aws_lb.vonq.dns_name
    zone_id                = aws_lb.vonq.zone_id
    evaluate_target_health = true
  }
}

# Primary failover record - use main domain
resource "aws_route53_record" "primary_failover" {
  count   = var.primary_region ? 1 : 0
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier = "primary-failover"
  
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.alb_health.id

  alias {
    name                   = aws_lb.vonq.dns_name
    zone_id                = aws_lb.vonq.zone_id
    evaluate_target_health = true
  }
}

# Secondary region records
resource "aws_route53_record" "secondary_geo" {
  count   = var.primary_region ? 0 : 1
  zone_id = local.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  set_identifier = "secondary-na"
  
  geolocation_routing_policy {
    continent = "NA"
  }

  health_check_id = aws_route53_health_check.alb_health.id

  alias {
    name                   = aws_lb.vonq.dns_name
    zone_id                = aws_lb.vonq.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "secondary_failover" {
  count   = var.primary_region ? 0 : 1
  zone_id = local.zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier = "secondary-failover"
  
  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = aws_lb.vonq.dns_name
    zone_id                = aws_lb.vonq.zone_id
    evaluate_target_health = true
  }
}

# CNAME to redirect main domain to app subdomain
resource "aws_route53_record" "main_cname" {
  count   = var.primary_region ? 1 : 0
  zone_id = local.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = ["app.${var.domain_name}"]
}
