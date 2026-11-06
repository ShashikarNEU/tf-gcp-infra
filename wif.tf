# Workload Identity Federation: GitHub Actions exchanges its OIDC token for
# short-lived GCP credentials. No service-account JSON key stored in GitHub.
# AWS equivalent: IAM OIDC identity provider + role with a trust policy on the repo.

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # Only tokens minted for this GitHub account's repos are accepted.
  attribute_condition = "assertion.repository_owner == \"${var.github_owner}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Each listed repo may impersonate the CI service account, nothing else.
resource "google_service_account_iam_member" "github_wif" {
  for_each           = toset(var.github_repositories)
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.email_workflow}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}
