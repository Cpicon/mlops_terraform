# BigQuery Outputs
output "bigquery_dataset_id" {
  description = "The ID of the BigQuery dataset"
  value       = module.bigquery.dataset_id
}

output "bigquery_dataset_self_link" {
  description = "The self link of the BigQuery dataset"
  value       = module.bigquery.dataset_self_link
}

output "bigquery_transcripts_table_id" {
  description = "The ID of the transcripts table"
  value       = module.bigquery.transcripts_table_id
}

output "bigquery_transcripts_table_self_link" {
  description = "The self link of the transcripts table"
  value       = module.bigquery.transcripts_table_self_link
}

# Access Control Outputs
output "configured_access_summary" {
  description = "Summary of configured access levels"
  value = {
    data_owners = local.bigquery_access.data_owners
    data_editors = concat(
      local.bigquery_access.data_editors,
      [local.bigquery_access.ml_pipeline_sa]
    )
    data_viewers  = local.bigquery_access.data_viewers
    editor_groups = local.bigquery_access.data_editor_groups
    viewer_groups = local.bigquery_access.data_viewer_groups
  }
  sensitive = true # Contains email addresses
}

# Service Account Outputs
output "ml_pipeline_service_account" {
  description = "ML Pipeline service account email"
  value       = module.service_accounts.ml_pipeline_email
}