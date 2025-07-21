locals {
  project-id  = var.project_id
  region      = var.region
  # Define user mappings for different environments
  # These should be populated from terraform.tfvars
  user_mappings = var.user_mappings
}

## ==============================================
## Section 1: FILL IN CODE HERE TO REFERENCE RELEVANT MODULES
## ==============================================
