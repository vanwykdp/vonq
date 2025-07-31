output "load_balancer_ip" {
  description = "Public IP address of the load balancer"
  value       = google_compute_global_forwarding_rule.web_forwarding_rule.ip_address
}