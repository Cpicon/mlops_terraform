terraform {
  backend "gcs" {
    bucket = "mycompany-mlops-stage-terraform-state-20250720"
    prefix = "terraform/state"
    # TEMPORARY: Removed impersonation for WIF testing
    # WIF principal has direct access to bucket
    # impersonate_service_account = "terraform-stage@mycompany-mlops-stage.iam.gserviceaccount.com"
  }
}
