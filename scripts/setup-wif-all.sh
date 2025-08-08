#!/bin/bash
# Script to set up Workload Identity Federation for all environments at once
# This ensures consistency across all environments with the same repo and org

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hardcoded values (standardized across project to match GitHub Actions workflows)
POOL_ID="github-pool"
PROVIDER_ID="github-provider"

# Parameters from command line
GITHUB_ORG=""
GITHUB_REPO=""

# Function to display usage
usage() {
    echo "Usage: $0 -o GITHUB_ORG -r GITHUB_REPO"
    echo "  -o GITHUB_ORG    GitHub organization/username"
    echo "  -r GITHUB_REPO   GitHub repository name"
    echo "  -h               Show this help message"
    echo ""
    echo "This script sets up WIF for ALL environments (dev, stage, prod) at once"
    echo "ensuring they all use the same GitHub repository configuration."
    echo ""
    echo "Example:"
    echo "  $0 -o Cpicon -r mlops_terraform"
    exit 1
}

# Parse command line arguments
while getopts "o:r:h" opt; do
    case $opt in
        o) GITHUB_ORG="$OPTARG";;
        r) GITHUB_REPO="$OPTARG";;
        h) usage;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage;;
    esac
done

# Validate required parameters
if [[ -z "$GITHUB_ORG" || -z "$GITHUB_REPO" ]]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    usage
fi

# Load environment variables
if [ ! -f .env-mlops ]; then
    echo -e "${RED}Error: .env-mlops file not found${NC}"
    echo "Please run: just setup-vars"
    exit 1
fi

source .env-mlops

echo -e "${GREEN}=== Setting up WIF for ALL Environments ===${NC}"
echo "GitHub Organization: $GITHUB_ORG"
echo "GitHub Repository: $GITHUB_REPO"
echo ""

# Track success for each environment
FAILED_ENVS=()
PROJECT_NUMBERS=()

# Function to setup WIF for a single environment
setup_wif_for_env() {
    local ENV=$1
    local PROJECT=$2
    
    echo -e "${BLUE}Setting up WIF for $ENV environment...${NC}"
    echo "Project: $PROJECT"
    
    # Set the project
    if ! gcloud config set project "$PROJECT" 2>/dev/null; then
        echo -e "${RED}Failed to set project $PROJECT${NC}"
        return 1
    fi
    
    # Enable required APIs
    echo "Enabling required APIs..."
    gcloud services enable iamcredentials.googleapis.com sts.googleapis.com 2>/dev/null || true
    
    # Get project number
    PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format="value(projectNumber)" 2>/dev/null || echo "")
    if [[ -z "$PROJECT_NUMBER" ]]; then
        echo -e "${RED}Failed to get project number for $PROJECT${NC}"
        return 1
    fi
    
    echo "Project Number: $PROJECT_NUMBER"
    PROJECT_NUMBERS+=("$ENV:$PROJECT_NUMBER")
    
    # Service account names
    SA_NAME="terraform-${ENV}"
    SA_EMAIL="${SA_NAME}@${PROJECT}.iam.gserviceaccount.com"
    RESOURCES_SA="terraform-${ENV}-resources@${PROJECT}.iam.gserviceaccount.com"
    
    # Check if service accounts exist
    if ! gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
        echo -e "${YELLOW}Warning: Service account $SA_EMAIL does not exist${NC}"
        echo "Please create it with: just create-service-accounts $ENV"
    fi
    
    # Create workload identity pool if it doesn't exist
    echo "Creating Workload Identity Pool..."
    if ! gcloud iam workload-identity-pools describe "$POOL_ID" --location=global &>/dev/null; then
        gcloud iam workload-identity-pools create "$POOL_ID" \
            --location=global \
            --display-name="GitHub Actions Pool" \
            --description="Pool for GitHub Actions authentication" \
            --quiet
        echo "Created Workload Identity Pool"
    else
        echo "Workload Identity Pool already exists"
    fi
    
    # Delete existing provider if it exists (to ensure clean state)
    if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
        --workload-identity-pool="$POOL_ID" \
        --location=global &>/dev/null; then
        echo "Deleting existing provider to ensure clean configuration..."
        gcloud iam workload-identity-pools providers delete "$PROVIDER_ID" \
            --workload-identity-pool="$POOL_ID" \
            --location=global \
            --quiet || true
        
        # Wait for deletion to complete
        echo "Waiting for provider deletion to complete..."
        sleep 5
    fi
    
    # Create workload identity provider with correct repository
    echo "Creating Workload Identity Provider..."
    gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
        --location=global \
        --workload-identity-pool="$POOL_ID" \
        --display-name="GitHub Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
        --issuer-uri="https://token.actions.githubusercontent.com" \
        --attribute-condition="assertion.repository == '${GITHUB_ORG}/${GITHUB_REPO}'" \
        --quiet
    
    echo "Created Workload Identity Provider with repository: ${GITHUB_ORG}/${GITHUB_REPO}"
    
    # Configure service account permissions
    echo "Configuring service account permissions..."
    
    # Member for specific repository
    MEMBER="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}"
    
    # Grant workloadIdentityUser role to main SA
    if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
        echo "Granting workloadIdentityUser to $SA_NAME..."
        gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
            --role="roles/iam.workloadIdentityUser" \
            --member="$MEMBER" \
            --quiet
    fi
    
    # Grant workloadIdentityUser role to resources SA if it exists
    if gcloud iam service-accounts describe "$RESOURCES_SA" &>/dev/null; then
        echo "Granting workloadIdentityUser to terraform-${ENV}-resources..."
        gcloud iam service-accounts add-iam-policy-binding "$RESOURCES_SA" \
            --role="roles/iam.workloadIdentityUser" \
            --member="$MEMBER" \
            --quiet
    fi
    
    echo -e "${GREEN}✓ WIF setup complete for $ENV environment${NC}"
    echo ""
    return 0
}

# Setup WIF for each environment
echo -e "${YELLOW}Processing Development environment...${NC}"
if ! setup_wif_for_env "dev" "$DEV_PROJECT"; then
    FAILED_ENVS+=("dev")
    echo -e "${RED}✗ Failed to setup WIF for dev${NC}"
fi

echo -e "${YELLOW}Processing Staging environment...${NC}"
if ! setup_wif_for_env "stage" "$STAGE_PROJECT"; then
    FAILED_ENVS+=("stage")
    echo -e "${RED}✗ Failed to setup WIF for stage${NC}"
fi

echo -e "${YELLOW}Processing Production environment...${NC}"
if ! setup_wif_for_env "prod" "$PROD_PROJECT"; then
    FAILED_ENVS+=("prod")
    echo -e "${RED}✗ Failed to setup WIF for prod${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}=== WIF Setup Summary ===${NC}"
echo ""

if [[ ${#FAILED_ENVS[@]} -eq 0 ]]; then
    echo -e "${GREEN}✓ Successfully configured WIF for all environments!${NC}"
    echo ""
    echo "All environments are configured to accept authentication from:"
    echo "  Repository: ${GITHUB_ORG}/${GITHUB_REPO}"
    echo ""
    echo "Project Numbers:"
    for pn in "${PROJECT_NUMBERS[@]}"; do
        IFS=':' read -r env num <<< "$pn"
        ENV_UPPER=$(echo "$env" | tr '[:lower:]' '[:upper:]')
        echo "  GCP_${ENV_UPPER}_PROJECT_NUMBER: $num"
    done
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Set GitHub secrets for project numbers:"
    echo "   just setup-project-secrets"
    echo ""
    echo "2. Verify the setup:"
    echo "   just verify-wif dev"
    echo "   just verify-wif stage"
    echo "   just verify-wif prod"
    echo ""
    echo "3. Test with GitHub Actions workflow"
else
    echo -e "${RED}✗ WIF setup failed for some environments:${NC}"
    for env in "${FAILED_ENVS[@]}"; do
        echo "  - $env"
    done
    echo ""
    echo "Please fix the issues and run this script again."
    exit 1
fi