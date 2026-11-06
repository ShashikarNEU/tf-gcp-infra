# DB connection details live in Secret Manager. VMs read them at boot with
# their own service account (see scripts/startup.sh.tftpl), so the password
# never appears in instance metadata.

locals {
  secrets = {
    db_name     = var.db_name
    db_ip       = google_sql_database_instance.mysql_instance.private_ip_address
    db_username = var.webapp_subnet_name
    db_password = random_password.password.result
    # Full key path, used by CI when it creates new instance templates
    vm-kms-encryption = google_kms_crypto_key.key_vm.id
  }

  # for_each over the names only: the map holds a sensitive value (the
  # password), and sensitive values can't be used as for_each arguments.
  secret_ids = toset(["db_name", "db_ip", "db_username", "db_password", "vm-kms-encryption"])
}

resource "google_secret_manager_secret" "app" {
  for_each  = local.secret_ids
  project   = var.project_id
  secret_id = each.key

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "app" {
  for_each    = local.secret_ids
  secret      = google_secret_manager_secret.app[each.key].id
  secret_data = local.secrets[each.key]
}

# Created empty on purpose so the API key never lands in Terraform state.
# Add the value once, out of band:
#   printf '%s' "<key>" | gcloud secrets versions add mailgun-api-key --data-file=-
resource "google_secret_manager_secret" "mailgun_api_key" {
  project   = var.project_id
  secret_id = "mailgun-api-key"

  replication {
    auto {}
  }
}

# The VM / Cloud Function service account can read these secrets, nothing else.
resource "google_secret_manager_secret_iam_member" "app_accessor" {
  for_each  = google_secret_manager_secret.app
  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.email}"
}

resource "google_secret_manager_secret_iam_member" "mailgun_accessor" {
  secret_id = google_secret_manager_secret.mailgun_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.email}"
}
