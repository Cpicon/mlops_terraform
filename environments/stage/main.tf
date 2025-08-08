locals {
  project_id = var.project_id
  region     = var.region
}

# GCS Bucket Module for stage environment
module "gcs_bucket" {
  source      = "../../modules/gcs-bucket"
  bucket_name = "${var.project_id}-mlops-data"
  region      = var.region
  labels = {
    environment = "stage"
    team        = "mlops"
    managed_by  = "terraform"
  }
}