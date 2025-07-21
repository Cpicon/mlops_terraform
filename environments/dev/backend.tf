terraform {
  backend "gcs" {
    bucket = "mycompany-mlops-dev-terraform-state"
    prefix = "terraform/state"
    # Use Application Default Credentials (user must be logged in)
    # User will impersonate the state management service account
    impersonate_service_account = "terraform-dev@mycompany-mlops-dev.iam.gserviceaccount.com"
  }
}
