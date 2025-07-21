terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0"
    }
  }
  required_version = ">= 1.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  # Use Application Default Credentials (user must be logged in with gcloud)
  # The user's credentials will be used to impersonate the executor service account
  
  # Impersonate the executor service account for all resource operations
  impersonate_service_account = "terraform-prod-resources@mycompany-mlops-prod.iam.gserviceaccount.com"
}
