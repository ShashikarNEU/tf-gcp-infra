resource "random_id" "bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "bucket" {
  name                        = "${random_id.bucket_prefix.hex}-gcf-source" # globally unique
  location                    = var.bucket_location
  uniform_bucket_level_access = true

  encryption {
    default_kms_key_name = google_kms_crypto_key.key_bucket.id
  }

  depends_on = [google_kms_crypto_key_iam_binding.crypto_key_bucket]
}

resource "google_storage_bucket_object" "default" {
  name   = var.bucket_name
  bucket = google_storage_bucket.bucket.name
  source = var.bucket_source # zipped function source (serverless-fork/function-source)
}

resource "google_cloudfunctions2_function" "function" {
  name        = var.cloud_function_name
  location    = var.region
  description = "Sends the email verification link for new users"

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point

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
      DB_IP_ADDRESS   = google_sql_database_instance.mysql_instance.private_ip_address
      DB_NAME         = var.db_name
      DB_USER         = var.webapp_subnet_name
      MAILGUN_DOMAIN  = var.mailgun_domain
      VERIFY_BASE_URL = var.verify_base_url
    }

    # Secrets are mounted from Secret Manager, not stored as plain env vars.
    secret_environment_variables {
      key        = "DB_PASSWORD"
      project_id = var.project_id
      secret     = google_secret_manager_secret.app["db_password"].secret_id
      version    = "latest"
    }

    secret_environment_variables {
      key        = "MAILGUN_API_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.mailgun_api_key.secret_id
      version    = "latest"
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = var.event_type
    pubsub_topic   = google_pubsub_topic.verify_email.id
    retry_policy   = var.retry_policy
  }

  depends_on = [
    google_secret_manager_secret_iam_member.app_accessor,
    google_secret_manager_secret_iam_member.mailgun_accessor,
  ]
}
