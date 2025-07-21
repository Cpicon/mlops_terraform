locals {
  project-id = var.project_id
  region     = var.region
  usernames = concat(var.dataset_owners, var.dataset_writers, var.dataset_readers)
  # BigQuery access mappings
  # This centralizes the mapping between user-friendly variable names 
  # and the BigQuery module's technical parameter names
  # Type: object with list(string) and string attributes
  bigquery_access = {
    # Individual users mapping:
    # dataset_owners  → data_owners  (BigQuery Data Owner role)
    # dataset_writers → data_editors (BigQuery Data Editor role)
    # dataset_readers → data_viewers (BigQuery Data Viewer role)
    data_owners  = var.dataset_owners
    data_editors = var.dataset_writers
    data_viewers = var.dataset_readers

    # Groups (convert single string to list if not empty)
    data_editor_groups = var.ml_team_group != "" ? [var.ml_team_group] : []
    data_viewer_groups = var.analysts_group != "" ? [var.analysts_group] : []

    # Service account for ML pipeline automation
    # This references the output from service_accounts module (created above)
    # The depends_on in bigquery module ensures this SA exists before IAM bindings
    ml_pipeline_sa = module.service_accounts.ml_pipeline_email
  }
}
# Service Accounts Module
# Creates service accounts needed for ML operations
module "service_accounts" {
  source = "../../modules/service-accounts"

  project_id = var.project_id
  all_users  = local.usernames  # Pass all users (owners, writers, readers) for logging access
}

# BigQuery Module for test data
module "bigquery" {
  source = "../../modules/big-query"

  # Ensure service accounts are created before BigQuery IAM bindings
  depends_on = [module.service_accounts]

  project_id          = var.project_id
  location            = var.region
  deletion_protection = false # Set to false for dev environment

  # Labels for resource organization
  labels = {
    environment = "dev"
    team        = "mlops"
    managed_by  = "terraform"
  }

  # IAM-based access control using locals mapping
  # All these attributes are defined in modules/big-query/variables.tf
  data_owners        = local.bigquery_access.data_owners
  data_editors       = local.bigquery_access.data_editors
  data_viewers       = local.bigquery_access.data_viewers
  data_editor_groups = local.bigquery_access.data_editor_groups
  data_viewer_groups = local.bigquery_access.data_viewer_groups
  ml_pipeline_sa     = local.bigquery_access.ml_pipeline_sa
}
