# Load Balancer
resource "aws_lb" "vonq" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = data.aws_subnets.public.ids
  
  tags = local.default_tags
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name_prefix}-target-group"
  port        = var.nginx_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vonq.id
  target_type = "ip"
  
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-299"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  
  tags = local.default_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.vonq.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}