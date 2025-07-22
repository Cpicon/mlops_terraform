#!/bin/bash
# Script to verify Workload Identity Federation setup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
POOL_ID="github-pool"
PROVIDER_ID="github-provider"
PROJECT_ID=""
ENVIRONMENT=""

# Function to display usage
usage() {
    echo "Usage: $0 -p PROJECT_ID -e ENVIRONMENT"
    echo "  -p PROJECT_ID    GCP Project ID"
    echo "  -e ENVIRONMENT   Environment (dev, stage, prod)"
    echo "  -h               Show this help message"
    exit 1
}

# Parse command line arguments
while getopts "p:e:h" opt; do
    case $opt in
        p) PROJECT_ID="$OPTARG";;
        e) ENVIRONMENT="$OPTARG";;
        h) usage;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage;;
    esac
done

# Validate required parameters
if [[ -z "$PROJECT_ID" || -z "$ENVIRONMENT" ]]; then
    echo -e "${RED}Error: Missing required parameters${NC}"
    usage
fi

# Service account name
SA_NAME="terraform-${ENVIRONMENT}"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo -e "${GREEN}Verifying Workload Identity Federation Setup${NC}"
echo "Project: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo ""

# Set the project
gcloud config set project "$PROJECT_ID" 2>/dev/null

# Get project number
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

# Check if APIs are enabled
echo -e "${YELLOW}Checking required APIs...${NC}"
APIS=("iamcredentials.googleapis.com" "sts.googleapis.com")
for api in "${APIS[@]}"; do
    if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
        echo -e "  ✅ $api is enabled"
    else
        echo -e "  ❌ $api is NOT enabled"
    fi
done

# Check workload identity pool
echo -e "\n${YELLOW}Checking Workload Identity Pool...${NC}"
if gcloud iam workload-identity-pools describe "$POOL_ID" --location=global &>/dev/null; then
    echo -e "  ✅ Workload Identity Pool '$POOL_ID' exists"
    
    # Get pool details
    POOL_NAME=$(gcloud iam workload-identity-pools describe "$POOL_ID" \
        --location=global --format="value(name)")
    echo "     Full name: $POOL_NAME"
else
    echo -e "  ❌ Workload Identity Pool '$POOL_ID' NOT found"
fi

# Check workload identity provider
echo -e "\n${YELLOW}Checking Workload Identity Provider...${NC}"
if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
    --workload-identity-pool="$POOL_ID" \
    --location=global &>/dev/null; then
    echo -e "  ✅ Workload Identity Provider '$PROVIDER_ID' exists"
    
    # Get provider details
    PROVIDER_DETAILS=$(gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
        --workload-identity-pool="$POOL_ID" \
        --location=global \
        --format="yaml(attributeCondition,attributeMapping,issuer)")
    echo "     Configuration:"
    echo "$PROVIDER_DETAILS" | sed 's/^/       /'
else
    echo -e "  ❌ Workload Identity Provider '$PROVIDER_ID' NOT found"
fi

# Check service account
echo -e "\n${YELLOW}Checking Service Account...${NC}"
if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    echo -e "  ✅ Service Account '$SA_EMAIL' exists"
    
    # Check IAM bindings
    echo "     Checking IAM bindings..."
    BINDINGS=$(gcloud iam service-accounts get-iam-policy "$SA_EMAIL" --format=json)
    
    if echo "$BINDINGS" | grep -q "roles/iam.workloadIdentityUser"; then
        echo -e "     ✅ workloadIdentityUser role is configured"
        
        # Show members with this role
        echo "     Members with workloadIdentityUser role:"
        echo "$BINDINGS" | jq -r '.bindings[] | select(.role == "roles/iam.workloadIdentityUser") | .members[]' | sed 's/^/       - /'
    else
        echo -e "     ❌ workloadIdentityUser role NOT configured"
    fi
else
    echo -e "  ❌ Service Account '$SA_EMAIL' NOT found"
fi

# Generate example GitHub Actions configuration
echo -e "\n${GREEN}=== GitHub Actions Configuration ===${NC}"
echo "Use this configuration in your GitHub Actions workflow:"
echo ""
echo "```yaml"
echo "- name: Authenticate to Google Cloud"
echo "  uses: google-github-actions/auth@v2"
echo "  with:"
echo "    workload_identity_provider: 'projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}'"
echo "    service_account: '${SA_EMAIL}'"
echo "```"
echo ""

# Summary
echo -e "${GREEN}=== Summary ===${NC}"
echo "Workload Identity Provider Path:"
echo "projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"
echo ""
echo "Service Account:"
echo "$SA_EMAIL"