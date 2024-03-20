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
  name                     = var.db_subnet_name
  region                   = var.region
  network                  = google_compute_network.vpc_network.self_link
  ip_cidr_range            = var.db_subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_route" "webapp_route" {
  name             = var.tf_route_name
  network          = google_compute_network.vpc_network.self_link
  dest_range       = var.dest_range_route
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  address_type  = "INTERNAL"
  prefix_length = 16
  purpose       = "VPC_PEERING"
  network       = google_compute_network.vpc_network.self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "mysql_instance" {
  name                = "mysql-instance-${random_id.db_name_suffix.hex}"
  database_version    = var.database_version
  region              = var.region
  deletion_protection = false
  depends_on          = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = var.sql_tier
    availability_type = var.routing_mode
    disk_type         = var.sql_disk_type
    disk_size         = var.size

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc_network.self_link
      enable_private_path_for_google_cloud_services = true
    }
  }
}

resource "google_sql_database" "mysql" {
  name     = var.webapp_subnet_name
  instance = google_sql_database_instance.mysql_instance.name
}

resource "random_password" "password" {
  length           = 12
  special          = true
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "~!@#$%^&*()_-+={}[]/<>,.;?':|"
}

resource "google_sql_user" "users" {
  name     = var.webapp_subnet_name
  instance = google_sql_database_instance.mysql_instance.name
  password = random_password.password.result
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

resource "google_service_account" "custom-service-account" {
  account_id   = "custom-service-account"
  display_name = "csa"
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

  metadata_startup_script = <<-EOF
    echo "DATABASE_URL=jdbc:mysql://${google_sql_database_instance.mysql_instance.private_ip_address}:3306/cloudDatabase?createDatabaseIfNotExist=true" > .env
    echo "DATABASE_USERNAME=${var.webapp_subnet_name}" >> .env
    echo "DATABASE_PASSWORD=${random_password.password.result}" >> .env
    sudo mv .env /opt/
    sudo chown csye6225:csye6225 /opt/.env
    sudo setenforce 0
    sudo systemctl daemon-reload
    sudo systemctl restart csye6225.service
  EOF

  service_account {
    email  = "${google_service_account.custom-service-account.account_id}@${var.project_id}.iam.gserviceaccount.com"
    scopes = var.scopes
  }
}

# fetching already created DNS zone
data "google_dns_managed_zone" "env_dns_zone" {
  name = var.domain_name
}

# to register web-server's ip address in DNS
resource "google_dns_record_set" "default" {
  name         = data.google_dns_managed_zone.env_dns_zone.dns_name
  managed_zone = data.google_dns_managed_zone.env_dns_zone.name
  type         = var.dns_type
  ttl          = var.ttl
  rrdatas = [
    google_compute_instance.vm-instance.network_interface[0].access_config[0].nat_ip
  ]
}

resource "google_project_iam_binding" "project" {
  project = var.project_id
  for_each = toset([
    "roles/logging.admin",
    "roles/monitoring.metricWriter"
  ])
  role = each.key

  members = [
    "serviceAccount:${google_service_account.custom-service-account.account_id}@${var.project_id}.iam.gserviceaccount.com"
  ]
}