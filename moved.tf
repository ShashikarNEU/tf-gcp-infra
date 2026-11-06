# Keeps existing state intact after splitting main.tf and moving the secrets
# into a for_each. Without these, Terraform would destroy and recreate them.

moved {
  from = google_secret_manager_secret.db-name-secret
  to   = google_secret_manager_secret.app["db_name"]
}

moved {
  from = google_secret_manager_secret_version.db-name-version
  to   = google_secret_manager_secret_version.app["db_name"]
}

moved {
  from = google_secret_manager_secret.db-ip-secret
  to   = google_secret_manager_secret.app["db_ip"]
}

moved {
  from = google_secret_manager_secret_version.db-ip-version
  to   = google_secret_manager_secret_version.app["db_ip"]
}

moved {
  from = google_secret_manager_secret.db-username-secret
  to   = google_secret_manager_secret.app["db_username"]
}

moved {
  from = google_secret_manager_secret_version.db-username-version
  to   = google_secret_manager_secret_version.app["db_username"]
}

moved {
  from = google_secret_manager_secret.db-password-secret
  to   = google_secret_manager_secret.app["db_password"]
}

moved {
  from = google_secret_manager_secret_version.db-password-version
  to   = google_secret_manager_secret_version.app["db_password"]
}

moved {
  from = google_secret_manager_secret.vm-kms-encryption
  to   = google_secret_manager_secret.app["vm-kms-encryption"]
}

moved {
  from = google_secret_manager_secret_version.vm-kms-encryption-version
  to   = google_secret_manager_secret_version.app["vm-kms-encryption"]
}

# google_project_iam_binding is authoritative: destroying it would strip the
# role from every member. Forget it from state instead, and let the
# non-authoritative google_project_iam_member grants in iam.tf take over.
removed {
  from = google_project_iam_binding.project

  lifecycle {
    destroy = false
  }
}
