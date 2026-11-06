resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_kms_key_ring" "keyring" {
  name     = "keyring-${random_id.db_name_suffix.hex}"
  location = var.region
}

# One customer-managed key (CMEK) per data store, rotated on a schedule.
resource "google_kms_crypto_key" "key_vm" {
  name            = "crypto-key-vm"
  key_ring        = google_kms_key_ring.keyring.id
  purpose         = var.purpose
  rotation_period = var.rotation_period

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_crypto_key" "key_bucket" {
  name            = "crypto-key-bucket"
  key_ring        = google_kms_key_ring.keyring.id
  purpose         = var.purpose
  rotation_period = var.rotation_period

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_crypto_key" "key_sql" {
  name            = "crypto-key-sql"
  key_ring        = google_kms_key_ring.keyring.id
  purpose         = var.purpose
  rotation_period = var.rotation_period

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

# Each Google service agent may use only its own key.
resource "google_kms_crypto_key_iam_binding" "crypto_key_vm" {
  crypto_key_id = google_kms_crypto_key.key_vm.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members       = ["serviceAccount:${var.email_ce_service_agent}"]
}

resource "google_kms_crypto_key_iam_binding" "crypto_key_bucket" {
  crypto_key_id = google_kms_crypto_key.key_bucket.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members       = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_kms_crypto_key_iam_binding" "crypto_key_sql" {
  crypto_key_id = google_kms_crypto_key.key_sql.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  members       = ["serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}"]
}
