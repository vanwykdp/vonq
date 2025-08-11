# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "simple-vpc"
  auto_create_subnetworks = false
}

# Public Subnet
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "europe-west1"
  network       = google_compute_network.vpc.id
}

# Firewall rule for HTTP traffic
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

# Firewall rule for ICMP (ping)
resource "google_compute_firewall" "allow_icmp" {
  name    = "allow-icmp"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

# Firewall rule for SSH
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

# Health check
resource "google_compute_health_check" "web_health_check" {
  name = "web-health-check"

  http_health_check {
    port = "80"
  }
}

# Backend service using Cloud Armor (points to proxy instances)
resource "google_compute_backend_service" "web_backend" {
  name            = "web-backend-proxy-service"
  protocol        = "HTTP"
  timeout_sec     = 10
  security_policy = google_compute_security_policy.security_policy.id

  backend {
    group = google_compute_instance_group_manager.proxy_group.instance_group
  }

  health_checks = [google_compute_health_check.web_health_check.id]
}


# URL map
resource "google_compute_url_map" "web_url_map" {
  name            = "web-url-map"
  default_service = google_compute_backend_service.web_backend.id
}

# HTTP proxy
resource "google_compute_target_http_proxy" "web_proxy" {
  name    = "web-http-proxy"
  url_map = google_compute_url_map.web_url_map.id
}

# Global forwarding rule (load balancer)
resource "google_compute_global_forwarding_rule" "web_lb" {
  name       = "web-load-balancer"
  target     = google_compute_target_http_proxy.web_proxy.id
  port_range = "80"
}

# Private Subnet
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "europe-west1"
  network       = google_compute_network.vpc.id
}

# NAT Gateway for private instances
resource "google_compute_router" "router" {
  name    = "nat-router"
  region  = "europe-west1"
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat-gateway"
  router                             = google_compute_router.router.name
  region                             = "europe-west1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  subnetwork {
    name                    = google_compute_subnetwork.data_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Firewall for internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["private"]
}

# Cloud Armor security policy
resource "google_compute_security_policy" "security_policy" {
  name = "web-security-policy"

  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "origin.region_code == 'CN' || origin.region_code == 'RU'"
      }
    }
    description = "Block traffic from China and Russia"
  }

  rule {
    action   = "rate_based_ban"
    priority = "2000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 600
    }
    description = "Rate limiting rule"
  }

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }
}

# Data Subnet
resource "google_compute_subnetwork" "data_subnet" {
  name          = "data-subnet"
  ip_cidr_range = "10.0.3.0/24"
  region        = "europe-west1"
  network       = google_compute_network.vpc.id
}

# Data subnet access from private subnet and proxies
resource "google_compute_firewall" "allow_data_access" {
  name    = "allow-data-access"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3306", "4444", "4567", "4568"]
  }

  source_ranges = ["10.0.1.0/24", "10.0.2.0/24"]
  target_tags   = ["galera"]
}

# Galera cluster internal communication
resource "google_compute_firewall" "allow_galera_internal" {
  name    = "allow-galera-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3306", "4444", "4567", "4568"]
  }

  source_ranges = ["10.0.3.0/24"]
  target_tags   = ["galera"]
}

# SSH access to data subnet from bastion hosts
resource "google_compute_firewall" "allow_bastion_to_data" {
  name    = "allow-bastion-to-data"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion"]
  target_tags = ["galera"]
}

# Health check for MariaDB
resource "google_compute_region_health_check" "galera_health_check" {
  name   = "galera-health-check"
  region = "europe-west1"

  tcp_health_check {
    port = "3306"
  }
}

# Backend service for Galera cluster
resource "google_compute_region_backend_service" "galera_backend" {
  name     = "galera-backend-service"
  region   = "europe-west1"
  protocol = "TCP"

  backend {
    group           = google_compute_instance_group.galera_group.id
    balancing_mode  = "CONNECTION"
  }

  health_checks = [google_compute_region_health_check.galera_health_check.id]
}


# Internal load balancer for Galera
resource "google_compute_forwarding_rule" "galera_lb" {
  name                  = "galera-lb"
  region                = "europe-west1"
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.galera_backend.id
  ports                 = ["3306"]
  network               = google_compute_network.vpc.name
  subnetwork           = google_compute_subnetwork.data_subnet.name
}

# Add to network.tf
resource "google_compute_firewall" "allow_galera_ssh" {
  name    = "allow-galera-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["81.107.114.107/32"]
  target_tags   = ["galera"]
}
