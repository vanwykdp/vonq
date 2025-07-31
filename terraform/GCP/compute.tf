# Instance template for autoscaling group
resource "google_compute_instance_template" "vm_template" {
  name         = "gcptutorials-template-v6"
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

  metadata_startup_script = <<-EOF
    #!/bin/bash
    exec > >(tee /var/log/startup.log) 2>&1
    
    echo "Starting startup script..."
    apt-get update
    apt-get install -y apache2
    
    echo "Creating index.html..."
    echo '{"message": "hello_world"}' > /var/www/html/index.html
    
    echo "Starting Apache..."
    systemctl start apache2
    systemctl enable apache2
    
    echo "Apache status:"
    systemctl status apache2
    
    echo "Testing local connection:"
    curl -I localhost
    
    echo "Startup script completed"
  EOF

  lifecycle {
    create_before_destroy = true
  }
}


# Instance template for autoscaling group
resource "google_compute_instance_template" "vm_template_2" {
  name         = "gcptutorials-template-v4"
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

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apache2
    
    echo '{"message": "hello_world"}' > /var/www/html/index.html
    
    systemctl start apache2
    systemctl enable apache2
  EOF

  lifecycle {
    create_before_destroy = true
  }
}

# Managed instance group with autoscaling
resource "google_compute_instance_group_manager" "vm_group_manager" {
  name = "gcptutorials-group-manager"
  zone = "europe-west1-b"

  version {
    instance_template = google_compute_instance_template.vm_template.id
  }

  base_instance_name = "gcptutorials-vm"
  target_size        = 2

  named_port {
    name = "http"
    port = 80
  }
}

# Autoscaler
resource "google_compute_autoscaler" "vm_autoscaler" {
  name   = "gcptutorials-autoscaler"
  zone   = "europe-west1-b"
  target = google_compute_instance_group_manager.vm_group_manager.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 2
    cooldown_period = 60

    metric {
      name   = "compute.googleapis.com/instance/memory/utilization"
      target = 0.8
      type   = "GAUGE"
    }
  }
}

