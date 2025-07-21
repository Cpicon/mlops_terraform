output "ml_pipeline_email" {
  description = "Email address of the ML pipeline service account"
  value       = google_service_account.ml_pipeline.email
}

output "ml_pipeline_id" {
  description = "Unique ID of the ML pipeline service account"
  value       = google_service_account.ml_pipeline.unique_id
}

output "ml_pipeline_name" {
  description = "Fully qualified name of the ML pipeline service account"
  value       = google_service_account.ml_pipeline.name
}