# ML Pipeline Service Account
# This service account is used for ML pipeline automation and data processing
resource "google_service_account" "ml_pipeline" {
  account_id   = "ml-pipeline"
  display_name = "ML Pipeline Service Account"
  description  = "Service account for ML pipeline automation, data processing, and BigQuery operations"
  project      = var.project_id
}

# Grant necessary roles to the ML pipeline service account
# BigQuery Job User - allows the SA to run BigQuery jobs
resource "google_project_iam_member" "ml_pipeline_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.ml_pipeline.email}"
}

# Additional roles can be added here as needed
# For example:
# - roles/storage.objectViewer for reading from GCS
# - roles/aiplatform.user for using Vertex AI
# - roles/pubsub.editor for Pub/Sub operations