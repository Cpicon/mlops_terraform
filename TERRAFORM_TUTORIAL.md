# Terraform MLOps Infrastructure Tutorial

Welcome to the Terraform MLOps Infrastructure tutorial! This guide will walk you through setting up infrastructure for Machine Learning Operations using Terraform on Google Cloud Platform with a streamlined CI/CD process using GitHub Actions.

## Overview

This tutorial follows the Pareto principle (80/20 rule) to get you productive quickly. You'll learn how to:
- Clone and set up the MLOps Terraform repository
- Configure GCP projects and service accounts using `justfile` automation
- Set up service account impersonation for secure access
- Configure GitHub Secrets for CI/CD pipeline variables
- Add new infrastructure modules
- Use the GitFlow process with CI/CD automation
- Create and merge pull requests with automated deployments

## Prerequisites

- **Google Cloud SDK**: Ensure you have installed the GCP command line tools (`gcloud`).
- **Terraform**: Version 1.0 or higher is required.
- **Just**: Task runner (`brew install just` on macOS)
- **Git**: To clone and manage your repository.
- **GitHub CLI**: For managing secrets (`brew install gh` on macOS)
- **GitHub Account**: With access to your organization's repository
- **GCP Billing Account**: With permissions to create projects

## Step-by-Step Setup

### 1. Configure Environment Variables

Use the `just` command to configure your environment:

```bash
just setup-vars
```

This command will prompt you to input your project IDs and regions, generate service account names, validate inputs, and save the configuration.

### 2. Authenticate with Google Cloud

Login and set up your application default credentials:

```bash
gcloud auth login
gcloud auth application-default login
source .env-mlops
```

### 3. Create GCP Projects with Billing

You can create all necessary projects at once or individually:

```bash
just create-projects --all
```

This will verify existing projects, create any that don't exist, and set up billing automatically.

### 4. Enable Required APIs

Enable the necessary APIs for your environments:

```bash
just enable-apis --all
```
### 5. Setup Terraform State Backend

Configure the backend for storing Terraform state files:

```bash
just setup-backend --all
```

### 6. Create Service Accounts

Create the required service accounts for all environments:

```bash
just create-service-accounts --all
```

### 7. Grant Impersonation Permissions

Grant impersonation permissions to your user account:

```bash
just grant-impersonation dev user:your-email@example.com
just grant-impersonation stage user:your-email@example.com
just grant-impersonation prod user:your-email@example.com
```

### 8. Setup Workload Identity Federation (For GitHub Actions)

Configure Workload Identity Federation to enable secure, keyless authentication from GitHub Actions to GCP:

```bash
just setup-wif dev <github-org> <github-repo>
```

**Example:**
If your repository is `https://github.com/johndoe/mlops-terraform`, you would run:
```bash
just setup-wif dev johndoe mlops-terraform
```
Where:
- `dev` = environment
- `johndoe` = your GitHub username (acts as the organization for personal repos)
- `mlops-terraform` = your repository name
```
# Output will show:
# ✅ dev environment variables validated
# 🔐 Setting up Workload Identity Federation for dev environment...
# Project Number: <long-number>
# Creating Workload Identity Pool...
# Creating Workload Identity Provider...
# Configuring service account permissions...
# Service account configured for Workload Identity Federation
```

#### How to Find Your GitHub Parameters

##### For a Personal Repository
If you have a personal GitHub repository, here's what you need:

**GitHub Organization (`GITHUB_ORG`)**
- **For personal repositories**: Use your **GitHub username**
- Example: If your GitHub profile is `https://github.com/johndoe`, then your organization is `johndoe`

**GitHub Repository (`GITHUB_REPO`)**
- **For any repository**: Use the **repository name** (without the organization)
- Example: If your repo URL is `https://github.com/johndoe/my-mlops-project`, then your repository name is `my-mlops-project`

##### How to Find These Values

**Method 1: From Your Repository URL**
If your repository URL is: `https://github.com/johndoe/mlops-infrastructure`
- `GITHUB_ORG` = `johndoe` (your username)
- `GITHUB_REPO` = `mlops-infrastructure` (repository name)

**Method 2: From GitHub Web Interface**
1. Go to your repository on GitHub
2. Look at the URL or the repository title at the top
3. Format: `<organization>/<repository>`

**Method 3: Using Git Command**
```bash
# In your local repository directory
git remote get-url origin
# Output: https://github.com/johndoe/mlops-infrastructure.git
# GITHUB_ORG = johndoe
# GITHUB_REPO = mlops-infrastructure
```

##### Important Notes
- **No prefixes needed**: Don't include `https://github.com/` or `.git`
- **Case sensitive**: Use exact capitalization as shown on GitHub
- **Personal accounts**: Your username serves as the organization name
- **Organization repos**: If you're part of a GitHub organization, use the organization name instead of your username

The Workload Identity Federation setup will:
1. Create a Workload Identity Pool named 'github-pool'
2. Create an OIDC Provider 'github-provider' that trusts GitHub
3. Grant the GitHub Actions service account permissions to impersonate:
   - `terraform-<env>@` service account (for state management)
   - `terraform-<env>-resources@` service account (for infrastructure provisioning)
4. Configure trust relationship for your specific repository and branches

#### Verify WIF Configuration

After setting up WIF, verify the configuration:

```bash
just verify-wif dev
```

**Example output:**
```bash
✅ dev environment variables validated
🔍 Verifying Workload Identity Federation for dev environment...

Checking required APIs...
  ✅ iamcredentials.googleapis.com is enabled
  ✅ sts.googleapis.com is enabled

Checking Workload Identity Pool...
  ✅ Workload Identity Pool 'github-pool' exists

Checking Workload Identity Provider...
  ✅ Workload Identity Provider 'github-provider' exists
     Configuration:
       attributeCondition: assertion.repository == 'johndoe/mlops-terraform'
       
Checking Service Account...
  ✅ Service Account 'terraform-dev@mycompany-mlops-dev.iam.gserviceaccount.com' exists
     ✅ workloadIdentityUser role is configured
```

This verification ensures:
- Required APIs are enabled
- WIF pool and provider exist correctly
- Service account has proper permissions
- Trust relationship is configured for your repository

### 9. Setup GitHub Secrets for CI/CD

Configure GitHub Secrets to provide Terraform variables to the CI/CD pipeline. These secrets are essential for GitHub Actions to deploy your infrastructure.

#### Prerequisites
- Ensure you have the GitHub CLI installed and authenticated:
  ```bash
  # Install GitHub CLI (if not already installed)
  brew install gh  # macOS
  # or visit: https://cli.github.com/
  
  # Authenticate with GitHub
  gh auth login
  ```

- Create your `terraform.tfvars` files for each environment:
  ```bash
  # Create tfvars files with your environment-specific values
  just create-tfvars dev
  just create-tfvars stage
  just create-tfvars prod
  
  # Edit each file to add your specific values
  # Example: environments/dev/terraform.tfvars
  ```

#### Set GitHub Secrets

Use the automated command to set up GitHub Secrets from your local `terraform.tfvars` files:

```bash
# Set secrets for all environments at once
just github-secrets add --all

# Or set for a specific environment
just github-secrets add dev
```

This command will:
- Read your local `terraform.tfvars` files
- Convert HCL list variables to JSON format automatically
- Create GitHub Secrets with the pattern `TF_VAR_{ENV}_{VARIABLE}` (uppercase)
- Handle both required and optional variables

#### Verify GitHub Secrets

To confirm your secrets are set correctly:

```bash
# List secrets for a specific environment
just github-secrets list dev

# Or check all environments
just github-secrets list --all
```

#### Important Notes

- **GitHub converts all secret names to UPPERCASE** automatically
- **Required secrets** (must be set):
  - `TF_VAR_{ENV}_PROJECT_ID`
  - `TF_VAR_{ENV}_REGION`
  - `TF_VAR_{ENV}_ZONE`
- **Optional secrets** (will use empty defaults if not set):
  - `TF_VAR_{ENV}_DATASET_OWNERS` (defaults to `[]`)
  - `TF_VAR_{ENV}_DATASET_WRITERS` (defaults to `[]`)
  - `TF_VAR_{ENV}_DATASET_READERS` (defaults to `[]`)
  - `TF_VAR_{ENV}_ML_TEAM_GROUP` (defaults to `''`)
  - `TF_VAR_{ENV}_ANALYSTS_GROUP` (defaults to `''`)

Don't forget to also set these repository-wide secrets:
- `GCP_PROJECT_NUMBER` - Your GCP project number
- `GCP_PROJECT_PREFIX` - Your project naming prefix (e.g., 'mycompany-mlops')

These can be set manually in GitHub UI or via CLI:
```bash
echo "1234567890" | gh secret set GCP_PROJECT_NUMBER
echo "mycompany-mlops" | gh secret set GCP_PROJECT_PREFIX
```

### 10. Initialize Terraform

Initialize the Terraform configuration for all environments:

```bash
just init --all
```

### 11. Deploy Infrastructure

Deploy the infrastructure using Terraform:

```bash
just plan dev
just apply dev
```

Repeat for staging and production environments as needed:
```bash
# For staging
just setup-wif stage <github-org> <github-repo>
just verify-wif stage
just plan stage
just apply stage

# For production
just setup-wif prod <github-org> <github-repo>
just verify-wif prod
just plan prod
just apply prod
```

### 12. Adding a New Module and Resource

Let's walk through adding a new Terraform module and resource to your infrastructure.

#### Example: Adding a Google Cloud Storage Bucket

1. **Create a New Branch**

   Start by creating a new branch to work on your feature:
   ```bash
   git checkout -b dev/add-gcs-bucket
   ```

2. **Create Module File Structure**

   Navigate to the `modules/` directory and create a new directory for the Cloud Storage module:
   ```bash
   mkdir -p modules/gcs-bucket
   touch modules/gcs-bucket/{main.tf,variables.tf,outputs.tf}
   ```

3. **Define the Storage Bucket in `main.tf`**

   Add the following code to `modules/gcs-bucket/main.tf`:
   ```hcl
   resource "google_storage_bucket" "example_bucket" {
     name     = var.bucket_name
     location = var.region
     force_destroy = true
     
     labels = var.labels
   }
   ```

4. **Specify Input Variables in `variables.tf`**

   Define required variables in `modules/gcs-bucket/variables.tf`:
   ```hcl
   variable "bucket_name" {
     description = "The name of the bucket"
     type        = string
   }
   
   variable "region" {
     description = "The region where the bucket will be created"
     type        = string
   }
   
   variable "labels" {
     description = "Labels applied to the bucket"
     type        = map(string)
     default     = {}
   }
   ```

5. **Output the Bucket's URL in `outputs.tf`**

   Add outputs to `modules/gcs-bucket/outputs.tf`:
   ```hcl
   output "bucket_url" {
     description = "The URL of the bucket"
     value       = google_storage_bucket.example_bucket.url
   }
   ```

6. **Integrate the Module in the Environment**

   Use the module in your environment configuration (e.g., `environments/dev/main.tf`):
   ```hcl
   module "gcs_bucket" {
     source     = "../../modules/gcs-bucket"
     bucket_name = "my-mlops-bucket"
     region     = var.region
     labels     = { "environment" = "dev" }
   }
   ```

7. **Plan and Apply Changes**

   Run Terraform to see and apply the changes:
   ```bash
   just plan dev
   just apply dev
   ```

8. **Commit and Push Changes**

   After testing, commit and push your changes:
   ```bash
   git add .
   git commit -m "Add Google Cloud Storage bucket module"
   git push origin dev/add-gcs-bucket
   ```

#### Example: Adding a Vertex AI Workflow

1. **Create a New Branch**

   Start by creating a new branch:
   ```bash
   git checkout -b dev/add-vertex-ai-workflow
   ```

2. **Create Module File Structure**

   Navigate to the `modules/` directory and create a new directory for the Vertex AI workflow:
   ```bash
   mkdir -p modules/vertex-ai-workflow
   touch modules/vertex-ai-workflow/{main.tf,variables.tf,outputs.tf}
   ```

3. **Define the Vertex AI Workflow in `main.tf`**

   Add the following code to `modules/vertex-ai-workflow/main.tf`:
   ```hcl
   resource "google_vertex_ai_workflow" "example_workflow" {
     name        = var.workflow_name
     display_name = var.display_name
     
     labels = var.labels
     region = var.region
     project = var.project_id
      
     container_spec {
       image_uri = var.image_uri
     }
   }
   ```

4. **Specify Input Variables in `variables.tf`**

   Define required variables in `modules/vertex-ai-workflow/variables.tf`:
   ```hcl
   variable "workflow_name" {
     description = "The name of the Vertex AI workflow"
     type        = string
   }

   variable "display_name" {
     description = "The display name of the workflow"
     type        = string
   }
   
   variable "image_uri" {
     description = "The container image URI"
     type        = string
   }
   
   variable "region" {
     description = "The region for the workflow"
     type        = string
   }
   
   variable "project_id" {
     description = "GCP Project ID"
     type        = string
   }

   variable "labels" {
     description = "Labels for the workflow"
     type        = map(string)
     default     = {}
   }
   ```

5. **Output Workflow Details in `outputs.tf`**

   Add outputs to `modules/vertex-ai-workflow/outputs.tf`:
   ```hcl
   output "workflow_id" {
     description = "The ID of the Vertex AI workflow"
     value       = google_vertex_ai_workflow.example_workflow.id
   }
   ```

6. **Integrate the Module in the Environment**

   Use the module in your environment configuration (e.g., `environments/dev/main.tf`):
   ```hcl
   module "vertex_ai_workflow" {
     source       = "../../modules/vertex-ai-workflow"
     workflow_name = "my-vertex-ai-workflow"
     display_name = "Vertex AI Workflow"
     image_uri    = "gcr.io/my-project/my-image"
     region       = var.region
     project_id   = var.project_id
     labels       = { "environment" = "dev" }
   }
   ```

7. **Plan and Apply Changes**

   Run Terraform to see and apply the changes:
   ```bash
   just plan dev
   just apply dev
   ```

8. **Commit and Push Changes**

   After testing, commit and push your changes:
   ```bash
   git add .
   git commit -m "Add Vertex AI workflow module"
   git push origin dev/add-vertex-ai-workflow
   ```

### 13. CI/CD Pipeline Management

Utilize GitHub Actions to automate your infrastructure deployments:

- **Development Branch**: Pushes to any `dev/*` branch will automatically deploy to the development environment.
- **Staging Branch**: Create a pull request to the `develop` branch, review the Terraform plan, and merge to deploy to staging.
- **Production Branch**: Create a pull request to the `main` branch, review the changes, and merge to deploy to production.

The pipeline validates and tests changes to ensure stability and control across environments.

**Important Prerequisites for CI/CD:**
- **Workload Identity Federation** (Step 8): Enables GitHub Actions to authenticate to GCP without service account keys
- **GitHub Secrets** (Step 9): Provides Terraform variables to the pipeline for each environment

### 14. Merging Pull Requests

1. After committing changes, push your branch:
   ```bash
   git push origin <your-feature-branch>
   ```

2. Navigate to your repository on GitHub.

3. Open a pull request:
   - From your feature branch to the `develop` branch for staging.
   - From the `develop` branch to the `main` branch for production.

4. Review the Terraform plan posted in the PR comments.

5. Once reviewed and approved, merge the PR to deploy the changes.

## Conclusion

This tutorial guides you through setting up and managing MLOps infrastructure using Terraform and GCP, complete with a CI/CD pipeline. Make sure to check for any environment-specific configurations and update as necessary. Happy deploying!
