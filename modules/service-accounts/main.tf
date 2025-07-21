# ML Pipeline Service Account
# This service account is used for ML pipeline automation and data processing
resource "google_service_account" "ml_pipeline" {
  account_id   = "ml-pipeline"
  display_name = "ML Pipeline Service Account"
  description  = "Service account for ML pipeline automation, data processing, and BigQuery operations"
  project      = var.project_id
}

# Grant necessary roles to the ML pipeline service account
# Note: google_project_iam_member requires one role per resource
# Multiple roles cannot be specified in a single resource
resource "google_project_iam_member" "ml_pipeline_bigquery_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.ml_pipeline.email}"
}

resource "google_project_iam_member" "ml_pipeline_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.ml_pipeline.email}"
}

resource "google_project_iam_member" "ml_pipeline_aiplatform_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.ml_pipeline.email}"
}

# Grant logging viewer roles to all users (owners, writers, readers)
# Each user needs separate resources for each role
resource "google_project_iam_member" "all_users_logging_viewer" {
  for_each = toset(var.all_users)
  
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "user:${each.value}"
}

resource "google_project_iam_member" "all_users_logging_view_accessor" {
  for_each = toset(var.all_users)
  
  project = var.project_id
  role    = "roles/logging.viewAccessor"
  member  = "user:${each.value}"
}