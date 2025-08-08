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