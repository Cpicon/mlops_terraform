#!/bin/bash
# Script to clean up old WIF bindings with incorrect repository names

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parameters
PROJECT_ID=""
ENVIRONMENT=""
OLD_REPO=""
NEW_REPO=""

# Function to display usage
usage() {
    echo "Usage: $0 -p PROJECT_ID -e ENVIRONMENT -o OLD_REPO -n NEW_REPO"
    echo "  -p PROJECT_ID    GCP Project ID"
    echo "  -e ENVIRONMENT   Environment (dev, stage, prod)"
    echo "  -o OLD_REPO      Old repository name (e.g., Cpicon/mlops-terraform)"
    echo "  -n NEW_REPO      New repository name (e.g., Cpicon/mlops_terraform)"
    echo "  -h               Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -p mycompany-mlops-stage -e stage -o Cpicon/mlops-terraform -n Cpicon/mlops_terraform"
    exit 1
}

# Parse command line arguments
while getopts "p:e:o:n:h" opt; do
    case $opt in
        p) PROJECT_ID="$OPTARG";;
        e) ENVIRONMENT="$OPTARG";;
        o) OLD_REPO="$OPTARG";;
        n) NEW_REPO="$OPTARG";;
        h) usage;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage;;
    esac
done

# Validate required parameters
if [[ -z "$PROJECT_ID" || -z "$ENVIRONMENT" || -z "$OLD_REPO" || -z "$NEW_REPO" ]]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    usage
fi

echo -e "${GREEN}Cleaning Up Old WIF Bindings${NC}"
echo "Project: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo "Old Repository: $OLD_REPO"
echo "New Repository: $NEW_REPO"
echo ""

# Set the project
gcloud config set project "$PROJECT_ID"

# Get project number
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

# Service accounts to check
SA_NAME="terraform-${ENVIRONMENT}"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
RESOURCES_SA="terraform-${ENVIRONMENT}-resources@${PROJECT_ID}.iam.gserviceaccount.com"

# Old member to remove
OLD_MEMBER="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/${OLD_REPO}"

echo -e "${YELLOW}Removing old bindings from service accounts...${NC}"

# Remove from main service account
echo "Checking $SA_EMAIL..."
if gcloud iam service-accounts get-iam-policy "$SA_EMAIL" --format=json | jq -e ".bindings[] | select(.role == \"roles/iam.workloadIdentityUser\") | .members[] | select(. == \"$OLD_MEMBER\")" > /dev/null 2>&1; then
    echo "  Removing old binding: $OLD_MEMBER"
    gcloud iam service-accounts remove-iam-policy-binding "$SA_EMAIL" \
        --role="roles/iam.workloadIdentityUser" \
        --member="$OLD_MEMBER" \
        --quiet
    echo -e "  ${GREEN}✓ Removed old binding${NC}"
else
    echo "  No old binding found"
fi

# Remove from resources service account if it exists
if gcloud iam service-accounts describe "$RESOURCES_SA" &>/dev/null; then
    echo "Checking $RESOURCES_SA..."
    if gcloud iam service-accounts get-iam-policy "$RESOURCES_SA" --format=json | jq -e ".bindings[] | select(.role == \"roles/iam.workloadIdentityUser\") | .members[] | select(. == \"$OLD_MEMBER\")" > /dev/null 2>&1; then
        echo "  Removing old binding: $OLD_MEMBER"
        gcloud iam service-accounts remove-iam-policy-binding "$RESOURCES_SA" \
            --role="roles/iam.workloadIdentityUser" \
            --member="$OLD_MEMBER" \
            --quiet
        echo -e "  ${GREEN}✓ Removed old binding${NC}"
    else
        echo "  No old binding found"
    fi
fi

echo ""
echo -e "${GREEN}=== Cleanup Complete ===${NC}"
echo ""
echo "Old bindings for repository '$OLD_REPO' have been removed."
echo "The service accounts now only accept authentication from '$NEW_REPO'."
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run this for other environments if needed"
echo "2. Re-run your GitHub Actions workflow to test authentication"