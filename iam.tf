# Non-authoritative grants: adds these members to each role without removing
# anyone else who already has it (google_project_iam_binding would).
locals {
  project_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/pubsub.publisher",
    "roles/cloudsql.client",
    "roles/cloudkms.cryptoKeyEncrypterDecrypter",
  ]

  project_members = [
    "serviceAccount:${var.email}",
    "serviceAccount:${var.email_workflow}",
  ]
}

resource "google_project_iam_member" "project" {
  for_each = {
    for pair in setproduct(local.project_roles, local.project_members) :
    "${pair[0]}|${pair[1]}" => { role = pair[0], member = pair[1] }
  }

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}
