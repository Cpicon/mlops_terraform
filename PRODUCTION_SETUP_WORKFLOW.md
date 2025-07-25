# Production Setup Workflow for MLOps Infrastructure

## Quick Start (TL;DR)

For experienced admins who want to get started immediately:

```bash
# 1. Setup environment variables
just setup-vars

# 2. Authenticate with Google Cloud as admin
gcloud auth login
gcloud auth application-default login

# 3. Create GCP projects with billing (if they don't exist)
just create-projects --all

# 4. Enable required APIs
just enable-apis --all

# 5. Create service accounts
just create-service-accounts --all

# 6. Setup backends (creates backend.tf files)
just setup-backend --all

# 7. Grant yourself impersonation access
just grant-impersonation dev --user your-email@company.com
just grant-impersonation stage --user your-email@company.com
just grant-impersonation prod --user your-email@company.com

# 8. Initialize Terraform with impersonation
just init --all

# 9. Deploy infrastructure
just plan dev
just apply dev
```

## Overview
This document provides step-by-step instructions for admins to set up Dev/Stage/Production environments for MLOps infrastructure using Terraform with a dual service account strategy:

- **terraform-{env}@** (tf-state-manager): Manages Terraform state with minimal permissions
- **terraform-{env}-resources@** (tf-executor): Provisions and manages infrastructure resources

This approach uses user impersonation instead of service account key files for enhanced security.

## 🏗️ Infrastructure Approach

### Authentication Strategy
The project uses a **dual service account pattern** with user impersonation:

1. **Bootstrap Phase** (One-time setup by admin):
   - Admin uses their own credentials to create initial resources
   - Creates service accounts, buckets, and IAM bindings
   - Grants impersonation rights to team members

2. **Steady State** (Ongoing operations):
   - Users authenticate with `gcloud auth application-default login`
   - Users impersonate service accounts for Terraform operations
   - No service account keys are downloaded or stored

### Project Structure
```
mlops_terraform/
├── main.tf                    # Shared infrastructure code
├── provider.tf               # Shared provider configuration
├── variables.tf              # Shared variable definitions
├── modules/                  # Shared Terraform modules
│   ├── big-query/           # BigQuery infrastructure
│   └── service-accounts/    # IAM and service accounts
├── environments/            # Environment-specific configurations
│   ├── dev/
│   │   ├── terraform.tfvars # Dev-specific variables
│   │   ├── backend.tf       # Dev state configuration
│   │   ├── main.tf          # Dev infrastructure
│   │   ├── variables.tf     # Dev variables
│   │   └── outputs.tf       # Dev outputs
│   ├── stage/
│   │   ├── terraform.tfvars # Stage-specific variables
│   │   ├── backend.tf       # Stage state configuration
│   │   └── ...              # Stage infrastructure files
│   └── prod/
│       ├── terraform.tfvars # Production-specific variables
│       ├── backend.tf       # Prod state configuration
│       └── ...              # Prod infrastructure files
├── justfile                 # Automation commands
└── setup-terraform-backend.sh # Backend setup script (deprecated)
```

### Key Benefits
- ✅ **Security First**: No service account keys stored locally or in repos
- ✅ **Dual SA Pattern**: Separation of state management and resource provisioning
- ✅ **User Impersonation**: Team members use their own identities with controlled access
- ✅ **Environment Isolation**: Each environment has dedicated buckets and service accounts
- ✅ **Audit Trail**: All actions traceable to individual users
- ✅ **Least Privilege**: Service accounts have minimal required permissions

## Prerequisites

### Required Tools
- Google Cloud SDK (`gcloud` CLI)
- Terraform >= 1.0
- Git

### Required Permissions

#### Bootstrap Phase (Admin)
Admin user must have these IAM roles:
- `roles/resourcemanager.projectIamAdmin`
- `roles/iam.serviceAccountAdmin`
- `roles/storage.admin`
- `roles/iam.serviceAccountTokenCreator` (to test impersonation)
- `roles/editor` (or higher)

#### Steady State (Team Members)
Team members need:
- `roles/iam.serviceAccountTokenCreator` on the terraform-{env}@ SA
- Granted via: `just grant-impersonation {env} user:email@company.com`

### Required Information
- GCP Project ID for each environment
- Service account names for each environment
- Preferred GCP regions/zones

## Step 1: Environment Setup

### 1.1 Interactive Setup (Recommended)
```bash
# Use the Justfile for streamlined setup
just setup-vars

# This command will:
# 1. Prompt for your project IDs and regions (with validation)
# 2. Generate service account names automatically  
# 3. Validate all inputs (errors on invalid project IDs)
# 4. Save configuration to .env-mlops for reuse
# 5. Export all variables to your current shell

# Check the configuration
just show-config
```

### 1.2 Quick Status Check
```bash
# Verify environment variables are properly configured
just status

# This shows the status of all environments:
# - Project and region configuration
# - Environment directory status
# - Terraform initialization status
# - Backend bucket status
```

## Step 2: GCP Authentication

### 2.1 Authenticate Admin User
```bash
# Login as admin user
gcloud auth login

# Setup Application Default Credentials (ADC)
gcloud auth application-default login

# List available projects (to verify access)
gcloud projects list

# Load environment variables for the rest of the setup
source .env-mlops
```

**Important**: The `gcloud auth application-default login` command is crucial as it sets up the credentials that Terraform will use for impersonation.

## Step 3: GCP Project Creation

### 3.1 Create Projects with Billing (If They Don't Exist)
```bash
# Option A: Create all projects at once (recommended)
just create-projects --all

# Option B: Create projects individually
just create-projects dev
just create-projects stage
just create-projects prod

# This command will:
# - Check if projects already exist
# - Create projects with appropriate names
# - Automatically set up billing (required for API enablement)
# - Verify billing is properly configured

# Billing Setup Process:
# 1. If you have only one billing account, it will be used automatically
# 2. If you have multiple billing accounts, you'll be prompted to choose one
# 3. If no billing accounts exist, you'll get guidance to create one

# Prerequisites for billing:
# - At least one active billing account in your Google Cloud organization
# - Billing admin permissions (roles/billing.admin or roles/billing.projectManager)
```

### 3.2 Verify Project Access and Billing
```bash
# Verify you can access all projects
gcloud projects list

# Check specific projects exist and have billing enabled
gcloud projects describe ${DEV_PROJECT}
gcloud billing projects describe ${DEV_PROJECT}

gcloud projects describe ${STAGE_PROJECT}
gcloud billing projects describe ${STAGE_PROJECT}

gcloud projects describe ${PROD_PROJECT}
gcloud billing projects describe ${PROD_PROJECT}
```

### 3.3 Troubleshooting Billing Issues

**Common billing setup issues and solutions:**

#### No Billing Accounts Available
```bash
# Problem: "No active billing accounts found"
# Solution: Create a billing account or get permissions

# Check if you have any billing accounts
gcloud billing accounts list

# If empty, create one at: https://console.cloud.google.com/billing
# Or contact your organization admin for access
```

#### Multiple Billing Accounts
```bash
# If you have multiple billing accounts, the command will show:
# ACCOUNT_ID            NAME                OPEN
# 01564E-510155-F8E7EB  My Billing Account  True
# 02345F-678901-A2B3C4  Org Billing         True

# Choose the appropriate one for your MLOps infrastructure
# Typically use your organization's main billing account for production
```

#### Billing Permissions
```bash
# Problem: "Failed to enable billing" or permission errors
# Solution: Ensure you have the right IAM roles

# Required roles for billing setup:
# - roles/billing.admin (full billing control)
# - roles/billing.projectManager (can link projects to billing)

# Check your billing permissions
gcloud projects get-iam-policy ${DEV_PROJECT} --filter="bindings.members:user:$(gcloud config get-value account)"
```

#### Projects in DELETE_REQUESTED State
```bash
# Problem: "Project is marked for deletion and cannot be used"
# Solution: Projects marked for deletion cannot be reactivated

# Check project state
gcloud projects describe ${DEV_PROJECT} --format="value(lifecycleState)"

# If DELETE_REQUESTED, you need to:
# 1. Wait for deletion to complete (up to 30 days)
# 2. Choose a different project ID in your .env-mlops file
# 3. Or contact Google Cloud support within 30 days to restore

# Update project IDs if needed
just setup-vars  # Reconfigure with different project IDs
```

#### Manual Billing Setup
```bash
# If automatic billing setup fails, you can do it manually:

# List available billing accounts
gcloud billing accounts list

# Link each project to a billing account
gcloud billing projects link ${DEV_PROJECT} --billing-account=YOUR_BILLING_ACCOUNT_ID
gcloud billing projects link ${STAGE_PROJECT} --billing-account=YOUR_BILLING_ACCOUNT_ID
gcloud billing projects link ${PROD_PROJECT} --billing-account=YOUR_BILLING_ACCOUNT_ID

# Verify billing is enabled
gcloud billing projects describe ${DEV_PROJECT}
```

## Step 4: Enable Required APIs

### 4.1 Enable Required APIs
```bash
# Option A: Enable APIs for all environments at once (recommended)
just enable-apis --all

# Option B: Enable APIs for specific environments
just enable-apis dev
just enable-apis stage
just enable-apis prod

# The following APIs are enabled automatically:
# - compute.googleapis.com
# - storage-api.googleapis.com
# - iam.googleapis.com
# - bigquery.googleapis.com
# - aiplatform.googleapis.com
# - container.googleapis.com
# - cloudbuild.googleapis.com
```

## Step 5: Create Service Accounts

### 5.1 Create Dual Service Accounts
```bash
# Option A: Create service accounts for all environments at once (recommended)
just create-service-accounts --all

# Option B: Create service accounts for specific environments
just create-service-accounts dev
just create-service-accounts stage
just create-service-accounts prod

# This automatically creates two service accounts per environment:
# - terraform-{env}@ for state management (minimal permissions)
# - terraform-{env}-resources@ for resource provisioning (broader permissions)
```

## Step 6: Setup Terraform Backend

### 6.1 Create Backend Configuration
```bash
# Option A: Setup all environments at once (recommended)
just setup --all

# Option B: Setup specific environments
just setup dev
just setup stage
just setup prod

# This automatically:
# - Creates dedicated GCS buckets for each environment
# - Generates backend.tf with impersonation config for terraform-{env}@

# NOTE: Service accounts must already exist!
# They were created in Step 5 with 'just create-service-accounts --all'
```

### 6.2 Grant Impersonation Access
```bash
# Grant yourself access to impersonate the service accounts
just grant-impersonation dev user:your-email@company.com
]]

# For groups (recommended for teams)
just grant-impersonation dev group:dev-team@company.com
# This grants:
# - roles/iam.serviceAccountTokenCreator on terraform-{env}@
# - Allows users to impersonate the SA for Terraform operations
```

### 7.3 Clone Repository (If Not Already Done)
```bash
# Clone the MLOps Terraform repository
git clone <repository-url>
cd mlops_terraform
```

## Step 7: Initialize Terraform

### 7.1 Initialize Terraform for dev Environments
```bash

just init dev

# This:
# - Uses your ADC credentials to impersonate terraform-{env}@
# - Initializes backend with the dedicated state bucket
# - Downloads required providers
# - Validates the configuration
```

### 7.2 Verify Impersonation is Working
```bash
# Test that you can plan changes (uses impersonation)
just plan dev

# If you see permission errors, ensure:
# 1. You have run 'gcloud auth application-default login'
# 2. You have been granted impersonation rights
# 3. The service accounts have correct permissions
```

## Step 8: Deploy Infrastructure

### 8.1 Deploy to Development
```bash
# Plan changes
just plan dev

# Apply changes (auto-approved for dev)
just apply dev

# The plan/apply commands:
# - Use your ADC to impersonate terraform-dev@
# - terraform-dev@ accesses the state bucket
# - terraform-dev@ impersonates terraform-dev-resources@
# - terraform-dev-resources@ creates the actual resources
```

### 8.2 Verify CI/CD Pipeline
```bash
# IMPORTANT: Stage/Prod deployments happen ONLY through CI/CD

# Local verification only (no apply)
just plan stage  # Review what would change
just plan prod   # Review what would change

# Actual deployment process:
# 1. Push changes to feature branch
# 2. Create Pull Request
# 3. CI/CD runs terraform plan and posts results
# 4. After PR approval and merge to main:
#    - CI/CD applies to staging automatically
#    - Manual approval required in GitHub Actions for prod
#    - CI/CD applies to production after approval

# NEVER run 'just apply stage' or 'just apply prod' manually!
```

## Step 9: Team Access Management

### 9.1 Grant Team Access (Bootstrap Phase)
```bash
# Development Team - Full access to dev environment
just grant-impersonation dev group:groupdev-team@company.com
```

### 9.2 Move IAM to Terraform (Steady State)
```hcl
# After bootstrap, manage team access via Terraform
# In environments/{env}/main.tf:

module "iam" {
  source = "../../modules/service-accounts"
  
  # Grant impersonation to groups
  sa_impersonators = {
    "terraform-${var.environment}@${var.project_id}.iam.gserviceaccount.com" = [
      "group:${var.environment}-team@company.com",
      "user:admin@company.com"
    ]
  }
  
  # Project-level IAM bindings
  project_iam_bindings = {
    "roles/viewer" = [
      "group:${var.environment}-team@company.com"
    ]
  }
}
```

## Step 10: Bootstrap vs Steady State Workflows

### 10.1 Bootstrap Workflow (One-time by Admin)
```bash
# Phase 1: Initial Setup
gcloud auth login
gcloud auth application-default login
just setup-vars
just create-projects --all
just enable-apis --all

# Phase 2: Create Service Accounts and Backend
just create-service-accounts --all  # Creates dual SAs with proper roles
just setup-backend --all  # Creates buckets and backend.tf files

# Phase 3: Grant Initial Access
just grant-impersonation dev user:admin@company.com
# Phase 4: Initialize and Test
just init dev
just plan dev
```

### 10.2 Steady State Workflow (Ongoing by Team)
```bash
# Developer Local Testing
gcloud auth application-default login  # One-time per session
cd mlops_terraform
just init dev
just plan dev    # Test changes locally

# Stage/Prod Deployment via CI/CD
git checkout -b dev/infrastructure-update
# Make changes
just plan dev    # Test locally first
just apply
git add .
git commit -m "feat: update infrastructure"
git push origin dev/infrastructure-update

# GitHub Actions automatically:
# 1. Runs terraform plan on PR creation
# 2. Posts plan results to PR
# 3. After merge to main:
#    - Applies to staging automatically
#    - Waits for manual approval for production
#    - Applies to production after approval

# CRITICAL: Never run 'apply' manually in stage/prod!
```

## Step 11: CI/CD Integration

### 11.1 Workload Identity Setup
```bash
# For each environment
just setup-wif dev YOUR_GITHUB_ORG YOUR_GITHUB_REPO
just setup-wif stage YOUR_GITHUB_ORG YOUR_GITHUB_REPO  
just setup-wif prod YOUR_GITHUB_ORG YOUR_GITHUB_REPO

# Verify setup
just verify-wif dev
just verify-wif stage
just verify-wif prod
```

### 11.2 GitHub Actions Configuration (Read [GITFLOW_PROCESS.md](./GITFLOW_PROCESS.md))
```bash
cat .github/workflows/terraform-apply.yml
```
## Step 12: Security Best Practices

### 12.1 No Service Account Keys
```bash
# The new workflow eliminates service account keys
# DO NOT download or store service account keys

# If you have existing keys, remove them:
rm -f *-terraform-key.json
rm -rf ~/.gcp/keys/

# All authentication is via impersonation
```

### 12.2 Audit and Monitoring
```bash

# Monitor impersonation events
gcloud logging read \
  'protoPayload.methodName="GenerateAccessToken" OR protoPayload.methodName="GenerateIdToken"' \
  --project=${DEV_PROJECT} \
  --limit=10
```

### 12.3 Regular Access Reviews
```bash
# List who can impersonate service accounts
for env in dev stage prod; do
  echo "=== $env environment ==="
  gcloud iam service-accounts get-iam-policy \
    terraform-${env}@mycompany-mlops-${env}.iam.gserviceaccount.com
done

# Remove access when no longer needed
just grant-impersonation dev user:former-employee@company.com --remove
```

## Step 13: Team Onboarding

### 13.1 For New Team Members
```bash
# 1. Ensure admin has granted you impersonation access
# Admin runs: just grant-impersonation {env} --user your-email@company.com

# 2. Setup local environment
git clone <repository-url>
cd mlops_terraform
just setup-vars  # Or get .env-mlops from admin

# 3. Authenticate
gcloud auth login
gcloud auth application-default login

# 4. Start working
just init dev        # Initialize Terraform
just plan dev        # Plan changes
just apply dev       # Apply changes
```

### 13.2 Daily Workflows

#### Development Team (Local Testing Only)
```bash
# Morning setup (once per day)
gcloud auth application-default login
cd mlops_terraform
git pull origin main

# Development workflow - LOCAL TESTING ONLY
just plan dev
# Create PR with changes - apply happens via CI/CD
```

#### Production Deployments (CI/CD Only)
```bash
# IMPORTANT: Production and Staging deployments MUST go through CI/CD
# Manual terraform apply is FORBIDDEN in stage/prod

# Correct workflow:
# 1. Create feature branch
git checkout -b dev/my-change

# 2. Make changes and test locally
just plan dev
just apply dev

# 3. Push and create PR
git push origin dev/my-change
# Create PR in GitHub

# 4. CI/CD runs automatically:
#    - terraform fmt -check
#    - terraform validate
#    - terraform plan (posts to PR)

# 5. After PR approval and merge:
#    - CI/CD runs terraform apply automatically
#    - Uses Workload Identity Federation (no keys)
#    - Applies to stage first, then prod after approval
```

### 13.3 Quick Reference

#### Admin Commands (Bootstrap)
```bash
# Initial setup
gcloud auth login
just setup-vars                      # Configure environment variables
just create-projects --all           # Create GCP projects
just enable-apis --all               # Enable required APIs
just create-service-accounts --all   # Create dual service accounts
just setup-backend --all             # Create buckets and backend.tf files

# Access management
just grant-impersonation dev user:email@company.com
just grant-impersonation dev group:team@company.com
just grant-impersonation dev --user email@company.com --remove
```

#### Developer Commands (Daily Use)
```bash
# Authentication (once per session)
gcloud auth application-default login

# Local development and testing
just init dev                        # Initialize dev environment
just plan dev                        # Plan changes in dev
just plan stage                      # Preview stage changes (no apply!)
just plan prod                       # Preview prod changes (no apply!)

# IMPORTANT: Only 'just apply dev' is allowed locally
# Stage/Prod must go through CI/CD pipeline

# Git workflow for stage/prod changes
git checkout -b dev/my-change    # Create feature branch
# Make your changes
just plan dev                      # Verify changes locally
git add .
git commit -m "feat: describe change"
git push origin dev/my-change    # Push to trigger CI/CD
# Create PR in GitHub - CI/CD handles the rest

# Status and debugging
just status                          # Check all environments
just show-config                     # Display configuration
```

## Verification Checklist

### Bootstrap Phase (Admin)
- [ ] Environment variables configured (`just setup-vars`)
- [ ] Admin authenticated with `gcloud auth login` and `gcloud auth application-default login`
- [ ] GCP projects created with billing (`just create-projects --all`)
- [ ] APIs enabled (`just enable-apis --all`)
- [ ] Service accounts created (`just create-service-accounts --all`)
- [ ] Backend infrastructure created (`just setup-backend --all`)
- [ ] Admin granted impersonation access (`just grant-impersonation --all --user admin@`)
- [ ] Terraform initialized (`just init --all`)
- [ ] Test deployment successful (`just plan dev`)

### Steady State (Team)
- [ ] Team members granted impersonation access
- [ ] No service account keys in repository or local machines
- [ ] All team members using `gcloud auth application-default login`
- [ ] IAM management moved to Terraform code
- [ ] CI/CD configured with Workload Identity (no keys)
- [ ] Audit logging enabled for service account usage
- [ ] Regular access reviews scheduled

## Troubleshooting

### Common Issues

#### Permission Denied on Impersonation
```bash
# Error: "Permission 'iam.serviceAccounts.getAccessToken' denied"
# Solution: Ensure you have been granted impersonation rights
just grant-impersonation dev --user your-email@company.com
```

#### ADC Not Set Up
```bash
# Error: "could not find default credentials"
# Solution: Setup Application Default Credentials
gcloud auth application-default login
```

#### Service Account Missing Permissions
```bash
# Error: "permission denied" when creating resources
# Solution: Ensure terraform-{env}-resources@ has required roles
gcloud projects get-iam-policy ${PROJECT} --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:terraform-${ENV}-resources@"
```

#### State Lock Issues
```bash
# Error: "Error acquiring the state lock"
# Solution: Check if another operation is running
# If stuck, manually unlock:
terraform force-unlock LOCK_ID -force
```

## Next Steps

1. **Immediate Actions**:
   - Remove any existing service account key files
   - Grant team members appropriate impersonation access
   - Update any scripts or CI/CD to use impersonation

2. **Infrastructure as Code**:
   - Move all IAM bindings to Terraform modules
   - Implement least-privilege policies in code
   - Add resource tagging and cost allocation

3. **Security Enhancements**:
   - Enable VPC Service Controls
   - Implement Binary Authorization for GKE
   - Set up Security Command Center
   - Configure Access Context Manager

4. **Automation**:
   - Set up GitHub Actions with Workload Identity
   - Implement automated security scanning
   - Create drift detection workflows
   - Build automated rollback procedures

5. **Monitoring**:
   - Configure alerts for service account usage
   - Set up cost anomaly detection
   - Implement SLOs for infrastructure availability
   - Create dashboards for resource utilization 