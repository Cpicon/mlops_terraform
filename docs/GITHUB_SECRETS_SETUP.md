# GitHub Secrets Setup for Terraform Variables

This document explains how to configure GitHub Secrets to provide Terraform variables for the CI/CD pipeline.

## Overview

Since `terraform.tfvars` files contain environment-specific and potentially sensitive configuration, they are not committed to the repository. Instead, we use GitHub Secrets to securely store these values and inject them as environment variables during the CI/CD pipeline execution.

## How It Works

1. **Local Development**: You create and maintain `terraform.tfvars` files locally
2. **GitHub Secrets**: Values from tfvars are stored as GitHub Secrets
3. **CI/CD Pipeline**: GitHub Actions injects these secrets as `TF_VAR_*` environment variables
4. **Terraform**: Automatically reads `TF_VAR_*` environment variables

## Required Secrets

### Repository-wide Secrets

These secrets are used across all environments:

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `GCP_PROJECT_NUMBER` | Your GCP project number | `1234567890` |
| `GCP_PROJECT_PREFIX` | Project naming prefix | `mycompany-mlops` |

### Environment-specific Secrets

For each environment (dev, stage, prod), you need:

| Secret Name Pattern | Type | Description | Example | Required |
|-------------------|------|-------------|---------|----------|
| `TF_VAR_{ENV}_PROJECT_ID` | String | GCP Project ID | `mycompany-mlops-dev` | ✅ |
| `TF_VAR_{ENV}_REGION` | String | GCP Region | `us-central1` | ✅ |
| `TF_VAR_{ENV}_ZONE` | String | GCP Zone | `us-central1-a` | ✅ |
| `TF_VAR_{ENV}_DATASET_OWNERS` | JSON Array | List of dataset owners | `["taki@abc.com"]` | ❌ (Optional) |
| `TF_VAR_{ENV}_DATASET_WRITERS` | JSON Array | List of dataset writers | `["john@abc.com","sarah@abc.com"]` | ❌ (Optional) |
| `TF_VAR_{ENV}_DATASET_READERS` | JSON Array | List of dataset readers | `["alice@abc.com","bob@abc.com"]` | ❌ (Optional) |
| `TF_VAR_{ENV}_ML_TEAM_GROUP` | String | ML team Google Group | `ml-team@abc.com` | ❌ (Optional) |
| `TF_VAR_{ENV}_ANALYSTS_GROUP` | String | Analysts Google Group | `analysts@abc.com` | ❌ (Optional) |

**Important Notes**: 
- GitHub automatically converts secret names to UPPERCASE
- Replace `{ENV}` with `DEV`, `STAGE`, or `PROD` (uppercase)
- Optional variables will use empty defaults if not set (empty string for strings, empty array `[]` for lists)

## Setup Methods

### Method 1: Automated Setup (Recommended)

Use the provided script to automatically create all secrets from your local tfvars files:

```bash
# Prerequisites
# 1. Install GitHub CLI
brew install gh  # macOS
# or visit: https://cli.github.com/

# 2. Authenticate with GitHub
gh auth login

# 3. Create your terraform.tfvars files
# Copy the examples and fill in your values
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
cp environments/stage/terraform.tfvars.example environments/stage/terraform.tfvars
cp environments/prod/terraform.tfvars.example environments/prod/terraform.tfvars
# Edit each file with your actual values

# 4. Run the setup script
./scripts/setup-github-secrets.sh -r yourorg/yourrepo

# Or for a specific environment only
./scripts/setup-github-secrets.sh -r yourorg/yourrepo -e dev

# Dry run to preview what will be created
./scripts/setup-github-secrets.sh -r yourorg/yourrepo --dry-run
```

### Method 2: Manual Setup via GitHub UI

1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add each secret with the appropriate name and value

**Example for dev environment:**

```
Name: TF_VAR_DEV_PROJECT_ID
Value: mycompany-mlops-dev

Name: TF_VAR_DEV_DATASET_OWNERS
Value: ["taki@abc.com","admin@abc.com"]
```

Note: GitHub will automatically convert these to uppercase even if you enter them in lowercase.

### Method 3: Manual Setup via GitHub CLI

```bash
# Set individual secrets (use uppercase for environment)
echo "mycompany-mlops-dev" | gh secret set TF_VAR_DEV_PROJECT_ID -R yourorg/yourrepo
echo "us-central1" | gh secret set TF_VAR_DEV_REGION -R yourorg/yourrepo
echo '["taki@abc.com"]' | gh secret set TF_VAR_DEV_DATASET_OWNERS -R yourorg/yourrepo

# List all secrets to verify
gh secret list -R yourorg/yourrepo
```

## Important Notes

### JSON Format for Lists

Terraform list variables must be stored as JSON arrays in GitHub Secrets:

- **Correct**: `["email1@abc.com","email2@abc.com"]`
- **Incorrect**: `email1@abc.com,email2@abc.com`

### Empty Values

If a variable should be empty:
- For strings: Use an empty string `""`
- For lists: Use an empty array `[]`

### Security Considerations

1. **Access Control**: Only users with repository admin access can view/modify secrets
2. **Audit Trail**: GitHub logs all secret operations
3. **No Logs**: GitHub automatically masks secret values in logs
4. **Rotation**: Regularly rotate sensitive values

### Troubleshooting

If Terraform can't find variables:

1. **Check secret names**: Must match exactly (GitHub stores them in UPPERCASE)
   - Pattern: `TF_VAR_{ENV}_{VARIABLE_NAME}` (all uppercase)
   - Example: `TF_VAR_DEV_PROJECT_ID` (not `TF_VAR_dev_PROJECT_ID`)

2. **Verify secrets exist**:
   ```bash
   gh secret list -R yourorg/yourrepo
   ```

3. **Check workflow logs**: Look for environment variable injection in the Terraform Plan step

4. **Test locally with environment variables**:
   ```bash
   export TF_VAR_project_id="mycompany-mlops-dev"
   export TF_VAR_dataset_owners='["test@example.com"]'
   terraform plan
   ```

## Updating Secrets

When you need to update values:

1. Update your local `terraform.tfvars` file
2. Run the setup script again (it will overwrite existing secrets)
3. Or update manually in GitHub UI/CLI

## Best Practices

1. **Keep tfvars files locally**: Never commit actual tfvars files
2. **Use examples**: Keep terraform.tfvars.example files updated as documentation
3. **Validate JSON**: Ensure list values are valid JSON arrays
4. **Test changes**: Use terraform plan locally before updating secrets
5. **Document changes**: Note significant configuration changes in PR descriptions

## Example terraform.tfvars

```hcl
# environments/dev/terraform.tfvars
project_id = "mycompany-mlops-dev"
region     = "us-central1"
zone       = "us-central1-a"

dataset_owners = [
  "taki@abc.com",
  "admin@abc.com"
]

dataset_writers = [
  "john@abc.com",
  "sarah@abc.com"
]

dataset_readers = [
  "alice@abc.com",
  "bob@abc.com"
]

ml_team_group  = "ml-team@abc.com"
analysts_group = "analysts@abc.com"
```

This will create the following secrets (GitHub stores them in uppercase):
- `TF_VAR_DEV_PROJECT_ID` = `"mycompany-mlops-dev"`
- `TF_VAR_DEV_REGION` = `"us-central1"`
- `TF_VAR_DEV_ZONE` = `"us-central1-a"`
- `TF_VAR_DEV_DATASET_OWNERS` = `["taki@abc.com","admin@abc.com"]` (optional)
- `TF_VAR_DEV_DATASET_WRITERS` = `["john@abc.com","sarah@abc.com"]` (optional)
- `TF_VAR_DEV_DATASET_READERS` = `["alice@abc.com","bob@abc.com"]` (optional)
- `TF_VAR_DEV_ML_TEAM_GROUP` = `"ml-team@abc.com"` (optional)
- `TF_VAR_DEV_ANALYSTS_GROUP` = `"analysts@abc.com"` (optional)