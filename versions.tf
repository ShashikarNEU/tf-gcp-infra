terraform {
  required_version = ">= 1.7" # moved + removed blocks

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.20"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.20"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state in GCS (locking is built in). Partial config so the bucket
  # isn't hardcoded:
  #   terraform init -backend-config="bucket=<state-bucket>" -backend-config="prefix=tf-gcp-infra"
  backend "gcs" {}
}
