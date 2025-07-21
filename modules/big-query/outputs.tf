output "dataset_id" {
  description = "The ID of the BigQuery dataset"
  value       = google_bigquery_dataset.test_data.dataset_id
}

output "dataset_self_link" {
  description = "The self link of the BigQuery dataset"
  value       = google_bigquery_dataset.test_data.self_link
}

output "transcripts_table_id" {
  description = "The ID of the transcripts table"
  value       = google_bigquery_table.transcripts.table_id
}

output "transcripts_table_self_link" {
  description = "The self link of the transcripts table"
  value       = google_bigquery_table.transcripts.self_link
}