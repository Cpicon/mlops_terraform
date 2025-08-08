#!/bin/bash
# Script to set up Workload Identity Federation for GitHub Actions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Hardcoded values (standardized across project to match GitHub Actions workflows)
POOL_ID="github-pool"
PROVIDER_ID="github-provider"

# Parameters from command line
GITHUB_ORG=""
GITHUB_REPO=""
PROJECT_ID=""
ENVIRONMENT=""

# Function to display usage
usage() {
    echo "Usage: $0 -p PROJECT_ID -e ENVIRONMENT -o GITHUB_ORG -r GITHUB_REPO"
    echo "  -p PROJECT_ID    GCP Project ID"
    echo "  -e ENVIRONMENT   Environment (dev, stage, prod)"
    echo "  -o GITHUB_ORG    GitHub organization name"
    echo "  -r GITHUB_REPO   GitHub repository name"
    echo "  -h               Show this help message"
    exit 1
}

# Parse command line arguments
while getopts "p:e:o:r:h" opt; do
    case $opt in
        p) PROJECT_ID="$OPTARG";;
        e) ENVIRONMENT="$OPTARG";;
        o) GITHUB_ORG="$OPTARG";;
        r) GITHUB_REPO="$OPTARG";;
        h) usage;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage;;
    esac
done

# Validate required parameters
if [[ -z "$PROJECT_ID" || -z "$ENVIRONMENT" || -z "$GITHUB_ORG" || -z "$GITHUB_REPO" ]]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    usage
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|stage|prod)$ ]]; then
    echo -e "${RED}Error: Environment must be dev, stage, or prod${NC}"
    exit 1
fi

# Service account name
SA_NAME="terraform-${ENVIRONMENT}"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo -e "${GREEN}Setting up Workload Identity Federation for GitHub Actions${NC}"
echo "Project: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "GitHub Org: $GITHUB_ORG"
echo "GitHub Repo: $GITHUB_REPO"
echo "Service Account: $SA_EMAIL"
echo ""

# Set the project
gcloud config set project "$PROJECT_ID"

# Enable required APIs
echo -e "${YELLOW}Enabling required APIs...${NC}"
gcloud services enable iamcredentials.googleapis.com
gcloud services enable sts.googleapis.com

# Get project number
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
echo "Project Number: $PROJECT_NUMBER"

# Create workload identity pool if it doesn't exist
echo -e "${YELLOW}Creating Workload Identity Pool...${NC}"
if ! gcloud iam workload-identity-pools describe "$POOL_ID" --location=global &>/dev/null; then
    gcloud iam workload-identity-pools create "$POOL_ID" \
        --location=global \
        --display-name="GitHub Actions Pool" \
        --description="Pool for GitHub Actions authentication"
    echo -e "${GREEN}Created Workload Identity Pool${NC}"
else
    echo "Workload Identity Pool already exists"
fi

# Create workload identity provider if it doesn't exist
echo -e "${YELLOW}Creating Workload Identity Provider...${NC}"
if ! gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
    --workload-identity-pool="$POOL_ID" \
    --location=global &>/dev/null; then
    
    gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
        --location=global \
        --workload-identity-pool="$POOL_ID" \
        --display-name="GitHub Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-condition="assertion.repository == '${GITHUB_ORG}/${GITHUB_REPO}'"
    
    echo -e "${GREEN}Created Workload Identity Provider${NC}"
else
    echo "Workload Identity Provider already exists"
fi

# Grant the service account permission to be impersonated by the workload identity
echo -e "${YELLOW}Configuring service account permissions...${NC}"

# For specific repository
MEMBER="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}"

# Grant workloadIdentityUser role
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --role="roles/iam.workloadIdentityUser" \
    --member="$MEMBER"

echo -e "${GREEN}Service account configured for Workload Identity Federation${NC}"

# Output the configuration
echo ""
echo -e "${GREEN}=== GitHub Actions Configuration ===${NC}"
echo "Add these secrets to your GitHub repository:"
echo ""
echo "GCP_PROJECT_NUMBER: $PROJECT_NUMBER"
echo "GCP_PROJECT_PREFIX: ${PROJECT_ID%-*}"
echo ""
echo "Workload Identity Provider:"
echo "projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"
echo ""
echo "Service Account:"
echo "$SA_EMAIL"
echo ""
echo -e "${GREEN}Setup complete!${NC}"