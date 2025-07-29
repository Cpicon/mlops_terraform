variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "zone" {
  description = "The GCP zone"
  type        = string
}

# User access configurations with roles
variable "dataset_owners" {
  description = "List of user emails who should have OWNER access to BigQuery datasets"
  type        = list(string)
  default     = []
}

variable "dataset_writers" {
  description = "List of user emails who should have WRITER access to BigQuery datasets"
  type        = list(string)
  default     = []
}

variable "dataset_readers" {
  description = "List of user emails who should have READER access to BigQuery datasets"
  type        = list(string)
  default     = []
}

variable "ml_team_group" {
  description = "Google Group email for ML team members with WRITER access"
  type        = string
  default     = ""
}

variable "analysts_group" {
  description = "Google Group email for analysts with READER access"
  type        = string
  default     = ""
}

variable "ml_pipeline_sa" {
  description = "Service account email for ML pipeline automation (deprecated - now created by service_accounts module)"
  type        = string
  default     = ""
}
