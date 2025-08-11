output "load_balancer_ip" {
  description = "Public IP of the load balancer"
  value       = google_compute_global_forwarding_rule.web_lb.ip_address
}

output "url_map_name" {
  description = "Name of the URL map"
  value       = google_compute_url_map.web_url_map.name
}

output "url_map_id" {
  description = "ID of the URL map"
  value       = google_compute_url_map.web_url_map.id
}

output "url_map_self_link" {
  description = "Self link of the URL map"
  value       = google_compute_url_map.web_url_map.self_link
}

output "internal_lb_ip" {
  description = "IP of the internal load balancer"
  value       = google_compute_forwarding_rule.internal_lb.ip_address
}

# output "galera_lb_ip" {
#   description = "Internal IP of the Galera load balancer"
#   value       = google_compute_forwarding_rule.galera_lb.ip_address
# }
