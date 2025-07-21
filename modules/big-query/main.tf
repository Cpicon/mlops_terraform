resource "google_bigquery_dataset" "test_data" {
  dataset_id                  = "test_data"
  friendly_name               = "Test Data Dataset"
  description                 = "Dataset for test data storage"
  location                    = var.location
  default_table_expiration_ms = var.default_table_expiration_ms
  project                     = var.project_id

  labels = var.labels

  # Note: Access is now managed through IAM bindings below
  # This provides better control and uses standard IAM roles
}

resource "google_bigquery_table" "transcripts" {
  dataset_id = google_bigquery_dataset.test_data.dataset_id
  table_id   = "transcripts"
  project    = var.project_id

  deletion_protection = var.deletion_protection

  labels = var.labels

  schema = jsonencode([
    {
      name        = "id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique identifier for the transcript"
    },
    {
      name        = "created_at"
      type        = "DATETIME"
      mode        = "REQUIRED"
      description = "Timestamp when the transcript was created"
    },
    {
      name        = "content"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Content of the transcript"
    }
  ])
}

# IAM Bindings for Dataset Access
# Using google_bigquery_dataset_iam_binding for each role

# Data Owners binding
resource "google_bigquery_dataset_iam_binding" "data_owners" {
  dataset_id = google_bigquery_dataset.test_data.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataOwner"

  members = [for email in var.data_owners :
    startswith(email, "serviceAccount:") ? email : "user:${email}"
  ]
}

# Data Editors binding
resource "google_bigquery_dataset_iam_binding" "data_editors" {
  dataset_id = google_bigquery_dataset.test_data.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"

  members = concat(
    # Individual users
    [for email in var.data_editors :
      startswith(email, "serviceAccount:") ? email : "user:${email}"
    ],
    # Groups
    [for group in var.data_editor_groups : "group:${group}"],
    # ML pipeline service account - handle if it already has serviceAccount: prefix
    var.ml_pipeline_sa != "" ? [
      startswith(var.ml_pipeline_sa, "serviceAccount:") ? var.ml_pipeline_sa : "serviceAccount:${var.ml_pipeline_sa}"
    ] : []
  )
}

# Data Viewers binding
resource "google_bigquery_dataset_iam_binding" "data_viewers" {
  dataset_id = google_bigquery_dataset.test_data.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"

  members = concat(
    # Individual users
    [for email in var.data_viewers :
      startswith(email, "serviceAccount:") ? email : "user:${email}"
    ],
    # Groups
    [for group in var.data_viewer_groups : "group:${group}"]
  )
}