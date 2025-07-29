# Dev Environment Configuration

This directory contains the Terraform configuration for the development environment.

## Configuration

### 1. Copy the example configuration

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2. Update terraform.tfvars with your values

Edit `terraform.tfvars` to set your project-specific values:

```hcl
# Basic settings
project_id = "your-company-mlops-dev"
region     = "us-central1"
zone       = "us-central1-a"

# BigQuery access - just add emails to the appropriate list
dataset_owners = [
  "taki@yourcompany.com",    # Head of AI
]

dataset_writers = [
  "john@yourcompany.com",    # Data Scientist
  "sarah@yourcompany.com",   # ML Engineer
]

dataset_readers = [
  "alice@yourcompany.com",   # Data Analyst
]

# Groups (optional)
ml_team_group  = "ml-team@yourcompany.com"
analysts_group = "analysts@yourcompany.com"
```

## Access Control Structure

The BigQuery dataset access is configured using a hierarchical approach:

### 1. Role-Based Access

- **OWNER**: Full control (project owners, head of AI)
- **WRITER**: Can read and modify data (ML team, data scientists)
- **READER**: Read-only access (analysts)

### 2. Access Methods

1. **Google Groups** (Recommended)
   - `ml_team_group`: All ML team members get WRITER access
   - `analysts_group`: All analysts get READER access

2. **Individual Users**
   - Defined in `user_mappings` with predefined roles
   - Additional users via `additional_dataset_access`

3. **Service Accounts**
   - ML pipeline automation service accounts

### 3. Managing Access

To add new users, simply add their email to the appropriate list:

```hcl
# For a new data scientist
dataset_writers = [
  "john@yourcompany.com",
  "sarah@yourcompany.com",
  "newuser@yourcompany.com",  # Just add the new user here
]
```

No need to modify any Terraform code - just update the list and apply!

## Module Dependencies

The environment configuration has explicit dependencies to ensure resources are created in the correct order:

```hcl
module "service_accounts" {
  # Creates ML pipeline service account
}

module "bigquery" {
  depends_on = [module.service_accounts]  # Explicit dependency
  # Uses service account from above module
  ml_pipeline_sa = module.service_accounts.ml_pipeline_email
}
```

This ensures:
1. Service accounts are created first
2. BigQuery IAM bindings can reference the service account emails
3. No "service account does not exist" errors

## Important Notes

- **terraform.tfvars is git-ignored** - Never commit this file
- **Terraform impersonation** is separate from data access
- **Groups are preferred** over individual user access for easier management
- **Service accounts** should be created before granting access

## Testing Access

After applying the configuration, test access using the provided scripts:

```bash
# Test as current user
python scripts/bigquery-tests/04_test_access_summary.py --project-id your-project-id

# Test specific operations
python scripts/bigquery-tests/01_test_data_upload.py --project-id your-project-id
```