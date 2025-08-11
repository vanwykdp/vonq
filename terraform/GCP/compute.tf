# Private web instances template
resource "google_compute_instance_template" "private_web_template" {
  name         = "private-web-template"
  machine_type = "e2-micro"

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.private_subnet.name
  }

  tags = ["private"]

  metadata = {
    startup-script = file("${path.module}/metadata_startup_script.sh")
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_template" "web_template_2" {
  name         = "web-template-2"
  machine_type = "e2-micro"

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.public_subnet.name
    
    access_config {
      // Ephemeral public IP
    }
  }

  tags = ["web"]

  metadata = {
    startup-script = file("${path.module}/metadata_startup_script.sh")
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Private web instances group
resource "google_compute_instance_group_manager" "private_web_group" {
  name = "private-web-group-manager"
  zone = "europe-west1-b"

  version {
    instance_template = google_compute_instance_template.private_web_template.id
  }

  base_instance_name = "private-web-vm"
  target_size        = 2

  named_port {
    name = "http"
    port = 80
  }
}

# Autoscaler
resource "google_compute_autoscaler" "web_autoscaler" {
  name   = "web-autoscaler"
  zone   = "europe-west1-b"
  target = google_compute_instance_group_manager.private_web_group.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 2
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}

# Internal load balancer
resource "google_compute_forwarding_rule" "internal_lb" {
  name                  = "internal-lb"
  region                = "europe-west1"
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.private_backend.id
  ports                 = ["80"]
  network               = google_compute_network.vpc.name
  subnetwork           = google_compute_subnetwork.private_subnet.name
}

resource "google_compute_region_backend_service" "private_backend" {
  name     = "private-backend-service"
  region   = "europe-west1"
  protocol = "TCP"

  backend {
    group           = google_compute_instance_group_manager.private_web_group.instance_group
    balancing_mode  = "CONNECTION"
  }

  health_checks = [google_compute_region_health_check.private_health_check.id]
}

resource "google_compute_region_health_check" "private_health_check" {
  name   = "private-health-check"
  region = "europe-west1"

  tcp_health_check {
    port = "80"
  }
}

# Keep only this one:
resource "google_compute_instance_template" "proxy_template" {
  name         = "proxy-template-v5"  # Change name to avoid conflict
  machine_type = "e2-micro"

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.public_subnet.name
    
    access_config {
      // Ephemeral public IP
    }
  }

  tags = ["web"]

  metadata = {
    ssh-keys = "darrylvanwyk:${file("id_rsa.pub")}"
    startup-script = templatefile("${path.module}/metadata_startup_script_proxy.tpl", {
      internal_lb_ip = google_compute_forwarding_rule.internal_lb.ip_address
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Update the instance group to use the single template:
resource "google_compute_instance_group_manager" "proxy_group" {
  name = "proxy-group-manager"
  zone = "europe-west1-b"

  version {
    instance_template = google_compute_instance_template.proxy_template.id
  }

  base_instance_name = "proxy-vm"
  target_size        = 2

  named_port {
    name = "http"
    port = 80
  }
}