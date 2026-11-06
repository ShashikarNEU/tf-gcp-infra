resource "google_sql_database_instance" "mysql_instance" {
  name                = "mysql-instance-${random_id.db_name_suffix.hex}"
  database_version    = var.database_version
  region              = var.region
  deletion_protection = false
  encryption_key_name = google_kms_crypto_key.key_sql.id

  depends_on = [
    google_service_networking_connection.private_vpc_connection,
    google_kms_crypto_key_iam_binding.crypto_key_sql,
  ]

  settings {
    tier              = var.sql_tier
    availability_type = var.sql_availability_type
    disk_type         = var.sql_disk_type
    disk_size         = var.size

    backup_configuration {
      enabled            = true
      binary_log_enabled = true # enables point-in-time recovery
    }

    ip_configuration {
      ipv4_enabled                                  = false # private IP only
      private_network                               = google_compute_network.vpc_network.self_link
      enable_private_path_for_google_cloud_services = true
    }
  }
}

# The app connects to var.db_name (see the startup script), so create that database.
resource "google_sql_database" "mysql" {
  name     = var.db_name
  instance = google_sql_database_instance.mysql_instance.name
}

resource "random_password" "password" {
  length           = 12
  special          = true
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "~!@#$%^&*()_-+={}[]<>.;?:|"
}

resource "google_sql_user" "users" {
  name     = var.webapp_subnet_name
  instance = google_sql_database_instance.mysql_instance.name
  password = random_password.password.result
}
