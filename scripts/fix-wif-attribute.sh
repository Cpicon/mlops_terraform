#!/bin/bash
# Script to fix WIF attribute condition for GitHub Actions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parameters
PROJECT_ID=""
ENVIRONMENT=""
GITHUB_ORG=""
GITHUB_REPO=""

# Function to display usage
usage() {
    echo "Usage: $0 -p PROJECT_ID -e ENVIRONMENT -o GITHUB_ORG -r GITHUB_REPO"
    echo "  -p PROJECT_ID    GCP Project ID"
    echo "  -e ENVIRONMENT   Environment (dev, stage, prod)"
    echo "  -o GITHUB_ORG    GitHub organization/username"
    echo "  -r GITHUB_REPO   GitHub repository name (exact name from GitHub)"
    echo "  -h               Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -p mycompany-mlops-stage -e stage -o Cpicon -r mlops_terraform"
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

echo -e "${GREEN}Fixing WIF Attribute Condition${NC}"
echo "Project: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "Repository: ${GITHUB_ORG}/${GITHUB_REPO}"
echo ""

# Set the project
gcloud config set project "$PROJECT_ID"

# Check current attribute condition
echo -e "${YELLOW}Checking current WIF provider configuration...${NC}"
CURRENT_CONDITION=$(gcloud iam workload-identity-pools providers describe github-provider \
    --workload-identity-pool="github-pool" \
    --location=global \
    --format="value(attributeCondition)" 2>/dev/null || echo "")

if [[ -n "$CURRENT_CONDITION" ]]; then
    echo "Current condition: $CURRENT_CONDITION"
else
    echo -e "${RED}WIF provider not found. Please run setup-wif.sh first.${NC}"
    exit 1
fi

# Update the WIF provider with the correct repository name
echo -e "${YELLOW}Updating WIF provider attribute condition...${NC}"

# Build the new attribute condition
# This allows the exact repository match
ATTRIBUTE_CONDITION="assertion.repository == '${GITHUB_ORG}/${GITHUB_REPO}'"

# Update the provider
gcloud iam workload-identity-pools providers update-oidc github-provider \
    --location=global \
    --workload-identity-pool="github-pool" \
    --attribute-condition="$ATTRIBUTE_CONDITION" \
    --quiet

echo -e "${GREEN}✓ Updated attribute condition to: $ATTRIBUTE_CONDITION${NC}"

# Also ensure service account bindings are correct
SA_NAME="terraform-${ENVIRONMENT}"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

# The principal for the specific repository
MEMBER="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/${GITHUB_ORG}/${GITHUB_REPO}"

echo -e "${YELLOW}Verifying service account IAM bindings...${NC}"

# Check if binding exists
EXISTING_BINDING=$(gcloud iam service-accounts get-iam-policy "$SA_EMAIL" \
    --format=json | jq -r --arg member "$MEMBER" '.bindings[] | select(.role == "roles/iam.workloadIdentityUser") | .members[] | select(. == $member)')

if [[ -z "$EXISTING_BINDING" ]]; then
    echo "Adding workloadIdentityUser binding..."
    gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
        --role="roles/iam.workloadIdentityUser" \
        --member="$MEMBER" \
        --quiet
    echo -e "${GREEN}✓ Added IAM binding${NC}"
else
    echo -e "${GREEN}✓ IAM binding already exists${NC}"
fi

# Also add binding for the resources service account
RESOURCES_SA="terraform-${ENVIRONMENT}-resources@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$RESOURCES_SA" &>/dev/null; then
    echo -e "${YELLOW}Checking resources service account bindings...${NC}"
    
    EXISTING_RESOURCES_BINDING=$(gcloud iam service-accounts get-iam-policy "$RESOURCES_SA" \
        --format=json 2>/dev/null | jq -r --arg member "$MEMBER" '.bindings[] | select(.role == "roles/iam.workloadIdentityUser") | .members[] | select(. == $member)' || echo "")
    
    if [[ -z "$EXISTING_RESOURCES_BINDING" ]]; then
        echo "Adding workloadIdentityUser binding for resources SA..."
        gcloud iam service-accounts add-iam-policy-binding "$RESOURCES_SA" \
            --role="roles/iam.workloadIdentityUser" \
            --member="$MEMBER" \
            --quiet
        echo -e "${GREEN}✓ Added IAM binding for resources SA${NC}"
    else
        echo -e "${GREEN}✓ Resources SA IAM binding already exists${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=== Fix Complete ===${NC}"
echo ""
echo "The WIF provider has been updated to accept tokens from:"
echo "  Repository: ${GITHUB_ORG}/${GITHUB_REPO}"
echo ""
echo "Service accounts configured:"
echo "  - $SA_EMAIL"
if gcloud iam service-accounts describe "$RESOURCES_SA" &>/dev/null; then
    echo "  - $RESOURCES_SA"
fi
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run this for other environments if needed:"
if [[ "$ENVIRONMENT" != "dev" ]]; then
    echo "   $0 -p <dev-project> -e dev -o $GITHUB_ORG -r $GITHUB_REPO"
fi
if [[ "$ENVIRONMENT" != "prod" ]]; then
    echo "   $0 -p <prod-project> -e prod -o $GITHUB_ORG -r $GITHUB_REPO"
fi
echo ""
echo "2. Re-run your GitHub Actions workflow"
echo ""
echo -e "${GREEN}The attribute condition error should now be resolved!${NC}"