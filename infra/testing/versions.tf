terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 9.0"
    }
  }
  # State lives in gs://<PROJECT_ID>-ectwin-tfstate (created by scripts/testing/bootstrap-ci-wif.sh).
  # Pass it at init time: terraform init -backend-config="bucket=<PROJECT_ID>-ectwin-tfstate"
  backend "gcs" {
    prefix = "ectwin/testing"
  }
}

provider "google" {
  project = var.project_id
}
