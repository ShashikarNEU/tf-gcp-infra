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

resource "google_kms_key_ring" "keyring" {
  name     = "keyring-name"
  location = var.region
}

resource "google_kms_crypto_key" "key" {
  name     = "crypto-key-name"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  rotation_period = "2592000s"

  lifecycle {
    prevent_destroy = false
  }
}

data "google_storage_project_service_account" "gcs_account" {
}

resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  provider = google-beta
  service  = "sqladmin.googleapis.com"
  project  = var.project_id
}

resource "google_kms_crypto_key_iam_binding" "crypto_key" {
  crypto_key_id = google_kms_crypto_key.key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}",
    "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}",
    "serviceAccount:${var.email_ce_service_agent}"
  ]
}

resource "google_sql_database_instance" "mysql_instance" {
  name                = "mysql-instance-${random_id.db_name_suffix.hex}"
  database_version    = var.database_version
  region              = var.region
  deletion_protection = false
  encryption_key_name = google_kms_crypto_key.key.id
  depends_on          = [google_service_networking_connection.private_vpc_connection, google_kms_crypto_key_iam_binding.crypto_key]


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
  target_tags   = var.target_tags
  source_ranges = [google_compute_global_forwarding_rule.default.ip_address]
}

resource "google_service_account" "custom-service-account" {
  account_id   = "custom-service-account"
  display_name = "csa"
}

resource "google_compute_firewall" "default" {
  name = "fw-allow-health-check"
  allow {
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = google_compute_network.vpc_network.self_link
  priority      = 1000
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = var.target_tags
}

resource "google_compute_region_instance_template" "instance_template" {
  name_prefix  = "instance-template-"
  machine_type = var.machine_type
  region       = var.region

  // boot disk
  disk {
    source_image = var.image
    disk_type    = var.type
    disk_size_gb = var.size
    auto_delete  = true

    disk_encryption_key {
      kms_key_self_link = google_kms_crypto_key.key.id
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.self_link

    subnetwork = google_compute_subnetwork.webapp_subnet.self_link

    access_config {

    }
  }

  metadata_startup_script = <<-EOF
    echo "DATABASE_URL=jdbc:mysql://${google_sql_database_instance.mysql_instance.private_ip_address}:3306/${var.db_name}?createDatabaseIfNotExist=true" > .env
    echo "DATABASE_USERNAME=${var.webapp_subnet_name}" >> .env
    echo "DATABASE_PASSWORD=${random_password.password.result}" >> .env
    sudo mv .env /opt/
    sudo chown csye6225:csye6225 /opt/.env
    sudo setenforce 0
    sudo systemctl daemon-reload
    sudo systemctl restart csye6225.service
  EOF

  service_account {
    email  = var.email
    scopes = var.scopes
  }
  tags = var.target_tags
}

# Creating secret
resource "google_secret_manager_secret" "db-name-secret" {
  project   = var.project_id
  secret_id = "db_name"

  replication {
    auto {}
  }
}

# Creating secret version with service account key
resource "google_secret_manager_secret_version" "db-name-version" {
  secret = google_secret_manager_secret.db-name-secret.id

  secret_data = var.db_name
}

# Creating secret
resource "google_secret_manager_secret" "db-ip-secret" {
  project   = var.project_id
  secret_id = "db_ip"

  replication {
    auto {}
  }
}

# Creating secret version with service account key
resource "google_secret_manager_secret_version" "db-ip-version" {
  secret = google_secret_manager_secret.db-ip-secret.id

  secret_data = google_sql_database_instance.mysql_instance.private_ip_address
}

# Creating secret
resource "google_secret_manager_secret" "db-username-secret" {
  project   = var.project_id
  secret_id = "db_username"

  replication {
    auto {}
  }
}

# Creating secret version with service account key
resource "google_secret_manager_secret_version" "db-username-version" {
  secret = google_secret_manager_secret.db-username-secret.id

  secret_data = var.webapp_subnet_name
}

# Creating secret
resource "google_secret_manager_secret" "db-password-secret" {
  project   = var.project_id
  secret_id = "db_password"

  replication {
    auto {}
  }
}

# Creating secret version with service account key
resource "google_secret_manager_secret_version" "db-password-version" {
  secret = google_secret_manager_secret.db-password-secret.id

  secret_data = random_password.password.result
}

resource "google_compute_health_check" "http2-health-check" {
  name        = "http2-health-check"
  description = "Health check via http2"

  timeout_sec         = var.timeout_sec
  check_interval_sec  = var.check_interval_sec
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold

  http_health_check {
    port         = var.port
    request_path = var.request_path
  }
}

resource "google_compute_region_instance_group_manager" "grp_manager" {
  name = "appserver-igm"

  base_instance_name = "app"
  region             = var.region

  version {
    instance_template = google_compute_region_instance_template.instance_template.id
  }

  named_port {
    name = var.webapp_subnet_name
    port = var.named_port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http2-health-check.id
    initial_delay_sec = var.initial_delay_sec
  }
}

resource "google_compute_region_autoscaler" "autoscaler" {
  name   = "my-region-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.grp_manager.id

  autoscaling_policy {
    max_replicas    = var.max_replicas
    min_replicas    = var.min_replicas
    cooldown_period = var.cooldown_period

    cpu_utilization {
      target = var.cpu_utilization_target
    }
  }
}

# forwarding rule
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "l7-xlb-forwarding-rule"
  load_balancing_scheme = var.load_balancing_scheme
  port_range            = var.port_range
  target                = google_compute_target_https_proxy.default.id
}

# http proxy
resource "google_compute_target_https_proxy" "default" {
  name    = "l7-xlb-target-https-proxy"
  url_map = google_compute_url_map.default.id
  ssl_certificates = [
    google_compute_managed_ssl_certificate.lb_default.name
  ]
  depends_on = [
    google_compute_managed_ssl_certificate.lb_default
  ]
}

# url map
resource "google_compute_url_map" "default" {
  name            = "l7-xlb-url-map"
  default_service = google_compute_backend_service.default.id
}

# backend service with custom request and response headers
resource "google_compute_backend_service" "default" {
  name                  = "l7-xlb-backend-service"
  protocol              = var.protocol
  port_name             = var.webapp_subnet_name
  load_balancing_scheme = var.load_balancing_scheme
  timeout_sec           = var.timeout_sec_backend_service
  health_checks         = [google_compute_health_check.http2-health-check.id]
  backend {
    group           = google_compute_region_instance_group_manager.grp_manager.instance_group
    balancing_mode  = var.balancing_mode
    capacity_scaler = var.capacity_scaler
  }
  log_config {
    enable = true
  }
}

resource "google_compute_managed_ssl_certificate" "lb_default" {
  name = "myservice-ssl-cert"

  managed {
    domains = [var.full_domain_name]
  }
}

# resource "google_compute_ssl_certificate" "namecheap_ssl_certif" {
#   name        = "namecheap-ssl-cert"
#   private_key = file("C:/CSYE 6225/tf-gcp-infra/sever.key")
#   certificate = file("C:/CSYE 6225/tf-gcp-infra/csye6225-cloud-project_me.crt")
# }

# fetching already created DNS zone
data "google_dns_managed_zone" "env_dns_zone" {
  name = var.domain_name
}

#to register web-server's ip address in DNS
resource "google_dns_record_set" "default" {
  name         = data.google_dns_managed_zone.env_dns_zone.dns_name
  managed_zone = data.google_dns_managed_zone.env_dns_zone.name
  type         = var.dns_type
  ttl          = var.ttl
  rrdatas = [
    google_compute_global_forwarding_rule.default.ip_address
  ]
}

resource "google_project_iam_binding" "project" {
  project = var.project_id
  for_each = toset([
    "roles/logging.admin",
    "roles/monitoring.metricWriter",
    "roles/pubsub.publisher",
    "roles/cloudsql.admin",
    "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  ])
  role = each.key

  members = [
    "serviceAccount:${var.email}", "serviceAccount:${var.email_workflow}"
  ]
}

resource "google_pubsub_topic" "verify_email" {
  name                       = var.pubsub_topic_name
  message_retention_duration = var.pubsub_topic_message_retention_duration
}

resource "google_pubsub_subscription" "verify_email_subscription" {
  name  = "verify_email_subscription"
  topic = google_pubsub_topic.verify_email.id
}

resource "random_id" "bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "bucket" {
  name                        = "${random_id.bucket_prefix.hex}-gcf-source" # Every bucket name must be globally unique
  location                    = var.bucket_location
  uniform_bucket_level_access = true

  encryption {
    default_kms_key_name = google_kms_crypto_key.key.id
  }

  depends_on = [google_kms_crypto_key_iam_binding.crypto_key]
}

resource "google_storage_bucket_object" "default" {
  name   = var.bucket_name
  bucket = google_storage_bucket.bucket.name
  source = var.bucket_source # Path to the zipped function source code
}

resource "google_vpc_access_connector" "connector" {
  name          = var.google_vpc_access_connector_name
  ip_cidr_range = var.vpc_ip_cidr_range
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
}

resource "google_cloudfunctions2_function" "function" {
  name        = var.cloud_function_name
  location    = var.region
  description = "a new function"

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point # Set the entry point

    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name
        object = google_storage_bucket_object.default.name
      }
    }
  }

  service_config {
    service_account_email         = var.email
    vpc_connector                 = google_vpc_access_connector.connector.id
    vpc_connector_egress_settings = var.vpc_connector_egress_settings
    environment_variables = {
      DB_IP_ADDRESS = google_sql_database_instance.mysql_instance.private_ip_address
      DB_NAME       = var.db_name
      DB_USER       = var.webapp_subnet_name
      DB_PASSWORD   = random_password.password.result
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = var.event_type
    pubsub_topic   = google_pubsub_topic.verify_email.id
    retry_policy   = var.retry_policy
  }
}