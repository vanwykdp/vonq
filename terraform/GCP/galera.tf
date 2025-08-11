# Persistent disks for Galera data
resource "google_compute_disk" "galera_data" {
  count = 3
  name  = "galera-data-${count.index}"
  type  = "pd-standard"
  zone  = "europe-west1-b"
  size  = 200
}

# Static IP addresses for Galera nodes
resource "google_compute_address" "galera_static_ip" {
  count        = 3
  name         = "galera-static-ip-${count.index}"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.data_subnet.id
  address      = "10.0.3.${count.index + 100}"
  region       = "europe-west1"
}

# Galera cluster nodes
resource "google_compute_instance" "galera_nodes" {
  count        = 3
  name         = "galera-node-${count.index}"
  machine_type = "e2-medium"
  zone         = "europe-west1-b"

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  attached_disk {
    source      = google_compute_disk.galera_data[count.index].id
    device_name = "galera-data"
  }

  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.data_subnet.name
    network_ip = google_compute_address.galera_static_ip[count.index].address
  }

    tags = ["galera", "web"]


  metadata = {
    ssh-keys = "darrylvanwyk:${file("id_rsa.pub")}"
    startup-script = templatefile("${path.module}/galera_bootstrap.tpl", {
      node_index = count.index
      node_name = "galera-node-${count.index}"
      node_ip   = "10.0.3.${count.index + 100}"
      cluster_nodes = "10.0.1.100,10.0.1.101,10.0.1.102"
    })
  }
}

# # Instance group for Galera nodes
# resource "google_compute_instance_group" "galera_group" {
#   name = "galera-instance-group"
#   zone = "europe-west1-b"
  
#   instances = google_compute_instance.galera_nodes[*].self_link
  
#   named_port {
#     name = "mysql"
#     port = 3306
#   }
# }
