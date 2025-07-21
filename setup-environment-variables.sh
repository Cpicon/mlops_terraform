#!/bin/bash

# =============================================================================
# Environment Variables Setup Script for MLOps Terraform Infrastructure
# =============================================================================
# This script helps admins set up the required environment variables for
# multi-environment (Dev/Stage/Prod) MLOps infrastructure deployment.
#
# Usage: source ./setup-environment-variables.sh
# Note: Use 'source' to export variables to your current shell session
# =============================================================================

echo "🚀 MLOps Terraform Environment Setup"
echo "===================================="
echo

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local varname="$3"
    
    echo -n "${prompt} [${default}]: "
    read input
    
    if [[ -z "$input" ]]; then
        export ${varname}="$default"
    else
        export ${varname}="$input"
    fi
}

# Function to validate GCP project ID format
validate_project_id() {
    local project_id="$1"
    if [[ ! "$project_id" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
        echo "❌ ERROR: '$project_id' is not a valid GCP project ID format"
        echo "   Valid format: lowercase letters, numbers, hyphens, 6-30 chars, start with letter"
        echo "   Examples: my-project-123, company-mlops-dev, prod-env-2024"
        echo ""
        echo "Please enter a valid project ID."
        return 1
    fi
    echo "✅ '$project_id' - valid project ID format"
    return 0
}

echo "📋 Step 1: Project Configuration"
echo "Enter your GCP project IDs for each environment:"
echo

# Get project IDs with validation
while true; do
    prompt_with_default "Development project ID" "mycompany-mlops-dev" "DEV_PROJECT"
    if validate_project_id "$DEV_PROJECT"; then
        break
    fi
    echo
done

while true; do
    prompt_with_default "Staging project ID" "mycompany-mlops-stage" "STAGE_PROJECT"
    if validate_project_id "$STAGE_PROJECT"; then
        break
    fi
    echo
done

while true; do
    prompt_with_default "Production project ID" "mycompany-mlops-prod" "PROD_PROJECT"
    if validate_project_id "$PROD_PROJECT"; then
        break
    fi
    echo
done

echo
echo "🌍 Step 2: Regional Configuration"
echo "Enter preferred GCP regions for each environment:"
echo

# Get regions
prompt_with_default "Development region" "us-central1" "DEV_REGION"
prompt_with_default "Staging region" "us-central1" "STAGE_REGION"
prompt_with_default "Production region" "us-east1" "PROD_REGION"

echo
echo "📧 Step 3: Service Account Configuration"
echo "Generating service account names based on your projects..."

# Generate service account names
export DEV_SA="terraform-dev@${DEV_PROJECT}.iam.gserviceaccount.com"
export STAGE_SA="terraform-stage@${STAGE_PROJECT}.iam.gserviceaccount.com"
export PROD_SA="terraform-prod@${PROD_PROJECT}.iam.gserviceaccount.com"

echo "✅ Service accounts configured:"
echo "   Development: ${DEV_SA}"
echo "   Staging: ${STAGE_SA}"
echo "   Production: ${PROD_SA}"

echo
echo "🎯 Step 4: Validation"
echo "Verifying all variables are set correctly..."

# Validation
if [[ -z "$DEV_PROJECT" || -z "$STAGE_PROJECT" || -z "$PROD_PROJECT" ]]; then
    echo "❌ ERROR: Some project variables are not set properly"
    exit 1
fi

if [[ -z "$DEV_REGION" || -z "$STAGE_REGION" || -z "$PROD_REGION" ]]; then
    echo "❌ ERROR: Some region variables are not set properly"
    exit 1
fi

if [[ -z "$DEV_SA" || -z "$STAGE_SA" || -z "$PROD_SA" ]]; then
    echo "❌ ERROR: Some service account variables are not set properly"
    exit 1
fi

echo "✅ All variables validated successfully!"
echo

# Create environment file for persistence
cat > .env-mlops << EOF
# MLOps Terraform Environment Variables
# Generated on $(date)

# Project Configuration
export DEV_PROJECT="${DEV_PROJECT}"
export STAGE_PROJECT="${STAGE_PROJECT}"
export PROD_PROJECT="${PROD_PROJECT}"

# Regional Configuration
export DEV_REGION="${DEV_REGION}"
export STAGE_REGION="${STAGE_REGION}"
export PROD_REGION="${PROD_REGION}"

# Service Account Configuration
export DEV_SA="${DEV_SA}"
export STAGE_SA="${STAGE_SA}"
export PROD_SA="${PROD_SA}"
EOF

echo "💾 Environment variables saved to .env-mlops"
echo "   To reload these variables later, run: source .env-mlops"
echo

echo "📋 Configuration Summary:"
echo "========================"
echo "Development Environment:"
echo "  Project: ${DEV_PROJECT}"
echo "  Region:  ${DEV_REGION}"
echo "  SA:      ${DEV_SA}"
echo
echo "Staging Environment:"
echo "  Project: ${STAGE_PROJECT}"
echo "  Region:  ${STAGE_REGION}"
echo "  SA:      ${STAGE_SA}"
echo
echo "Production Environment:"
echo "  Project: ${PROD_PROJECT}"
echo "  Region:  ${PROD_REGION}"
echo "  SA:      ${PROD_SA}"
echo

echo "🎉 Setup Complete!"
echo "You can now proceed with the PRODUCTION_SETUP_WORKFLOW.md starting from Step 2."
echo
echo "💡 Next steps:"
echo "1. Verify you have access to all three GCP projects"
echo "2. Follow PRODUCTION_SETUP_WORKFLOW.md from Step 2"
echo "3. Keep the .env-mlops file for future use" 