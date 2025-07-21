# BigQuery Module

This module creates a BigQuery dataset with tables and manages access using Google Cloud IAM bindings.

## Features

- Creates BigQuery dataset with configurable settings
- Creates tables with defined schemas
- Manages access using IAM bindings (not legacy dataset access)
- Supports individual users, groups, and service accounts

## Usage

```hcl
module "bigquery" {
  source = "../../modules/big-query"
  
  project_id          = "my-project"
  location           = "us-central1"
  deletion_protection = false  # Set to true for production
  
  labels = {
    environment = "dev"
    team        = "mlops"
  }
  
  # IAM-based access control
  data_owners = [
    "head-of-ai@company.com"
  ]
  
  data_editors = [
    "data-scientist@company.com",
    "ml-engineer@company.com"
  ]
  
  data_viewers = [
    "analyst@company.com"
  ]
  
  # Groups
  data_editor_groups = ["ml-team@company.com"]
  data_viewer_groups = ["analysts@company.com"]
  
  # Service account
  ml_pipeline_sa = "ml-pipeline@project.iam.gserviceaccount.com"
}
```

## IAM Roles

This module uses standard BigQuery IAM roles:

| Role | Permission Level | Use Case |
|------|-----------------|----------|
| `roles/bigquery.dataOwner` + `roles/bigquery.admin` | Full control + Admin | Dataset administrators, Head of AI |
| `roles/bigquery.dataEditor` | Read/Write | Data scientists, ML engineers |
| `roles/bigquery.dataViewer` | Read only | Analysts, reporting users |

**Note**: Data owners receive both `dataOwner` and `admin` roles for complete BigQuery administration capabilities.

## Why IAM Bindings?

We use `google_bigquery_dataset_iam_binding` instead of the legacy `dataset_access` because:

1. **Standard IAM roles**: Uses Google's predefined roles instead of legacy OWNER/WRITER/READER
2. **Better integration**: Works with Google Cloud IAM policies and conditions
3. **Clearer permissions**: Explicit about what each role can do
4. **Future-proof**: Google recommends IAM bindings for new deployments

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `project_id` | GCP project ID | `string` | Required |
| `location` | Dataset location | `string` | `"us-central1"` |
| `data_owners` | Users with dataOwner role | `list(string)` | `[]` |
| `data_editors` | Users with dataEditor role | `list(string)` | `[]` |
| `data_viewers` | Users with dataViewer role | `list(string)` | `[]` |
| `data_editor_groups` | Groups with dataEditor role | `list(string)` | `[]` |
| `data_viewer_groups` | Groups with dataViewer role | `list(string)` | `[]` |
| `ml_pipeline_sa` | ML pipeline service account | `string` | `""` |

## Outputs

| Name | Description |
|------|-------------|
| `dataset_id` | The BigQuery dataset ID |
| `dataset_self_link` | Dataset self link |
| `transcripts_table_id` | Transcripts table ID |
| `transcripts_table_self_link` | Transcripts table self link |