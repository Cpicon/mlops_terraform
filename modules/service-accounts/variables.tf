variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "all_users" {
  description = "List of all user emails who should have logging viewer access (owners, writers, readers)"
  type        = list(string)
  default     = []
}