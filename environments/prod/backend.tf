terraform {
  backend "gcs" {
    bucket = "mycompany-mlops-prod-terraform-state-20250720"
    prefix = "terraform/state"
    # Use Application Default Credentials (user must be logged in)
    # User will impersonate the state management service account
    impersonate_service_account = "terraform-prod@mycompany-mlops-prod.iam.gserviceaccount.com"
  }
}
