variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "location" {
  description = "The location for the BigQuery dataset"
  type        = string
  default     = "us-central1"
}

variable "default_table_expiration_ms" {
  description = "Default expiration time for tables in milliseconds"
  type        = number
  default     = null
}

variable "deletion_protection" {
  description = "Whether or not to protect BigQuery tables from deletion"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

# IAM-based access control variables
variable "data_owners" {
  description = "List of user emails who should have BigQuery Data Owner role"
  type        = list(string)
  default     = []
}

variable "data_editors" {
  description = "List of user emails who should have BigQuery Data Editor role"
  type        = list(string)
  default     = []
}

variable "data_viewers" {
  description = "List of user emails who should have BigQuery Data Viewer role"
  type        = list(string)
  default     = []
}

variable "data_editor_groups" {
  description = "List of Google Groups that should have BigQuery Data Editor role"
  type        = list(string)
  default     = []
}

variable "data_viewer_groups" {
  description = "List of Google Groups that should have BigQuery Data Viewer role"
  type        = list(string)
  default     = []
}

variable "ml_pipeline_sa" {
  description = "Service account email for ML pipeline (without serviceAccount: prefix)"
  type        = string
  default     = ""
}