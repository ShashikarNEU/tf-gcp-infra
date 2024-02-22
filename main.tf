provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {
  name          = var.webapp_subnet_name
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = var.webapp_subnet_cidr
}

resource "google_compute_subnetwork" "db_subnet" {
  name          = var.db_subnet_name
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = var.db_subnet_cidr
}

resource "google_compute_route" "webapp_route" {
  name             = var.tf_route_name
  network          = google_compute_network.vpc_network.self_link
  dest_range       = var.dest_range_route
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

resource "google_compute_firewall" "firewall_allow" {
  name    = var.firewall_allow_name
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = var.ports
  }

  priority      = 800
  source_tags   = var.source_tags
  source_ranges = var.source_ranges
}

resource "google_compute_firewall" "firewall_deny" {
  name    = var.firewall_deny_name
  network = google_compute_network.vpc_network.self_link


  deny {
    protocol = "all"
    ports    = []
  }

  source_tags   = var.source_tags
  target_tags   = var.target_tags
  source_ranges = var.source_ranges
}

resource "google_compute_instance" "vm-instance" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["vm-instance"]

  boot_disk {
    device_name = "instance-1"
    initialize_params {
      image = var.image
      size  = var.size
      type  = var.type
    }
  }

  // Local SSD disk
  scratch_disk {
    interface = var.interface
  }

  network_interface {
    network = google_compute_network.vpc_network.self_link

    subnetwork = google_compute_subnetwork.webapp_subnet.self_link

    access_config {
      // Ephemeral public IP
    }
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = var.email
    scopes = var.scopes
  }
}
