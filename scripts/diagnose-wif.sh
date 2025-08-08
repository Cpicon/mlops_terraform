#!/bin/bash
# Script to diagnose WIF configuration issues

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

# Function to display usage
usage() {
    echo "Usage: $0 -p PROJECT_ID -e ENVIRONMENT"
    echo "  -p PROJECT_ID    GCP Project ID"
    echo "  -e ENVIRONMENT   Environment (dev, stage, prod)"
    echo "  -h               Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -p mycompany-mlops-stage -e stage"
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

echo -e "${GREEN}=== WIF Configuration Diagnostic ===${NC}"
echo "Project: $PROJECT_ID"
echo "Environment: $ENVIRONMENT"
echo ""

# Set the project
gcloud config set project "$PROJECT_ID" 2>/dev/null

# Get project number
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)" 2>/dev/null || echo "ERROR")
echo -e "${BLUE}Project Number:${NC} $PROJECT_NUMBER"
echo ""

# Check if APIs are enabled
echo -e "${YELLOW}Checking required APIs...${NC}"
APIS_ENABLED=true
for api in iamcredentials.googleapis.com sts.googleapis.com; do
    if gcloud services list --enabled --filter="name:$api" --format="value(name)" 2>/dev/null | grep -q "$api"; then
        echo "✓ $api is enabled"
    else
        echo "✗ $api is NOT enabled"
        APIS_ENABLED=false
    fi
done
echo ""

# Check Workload Identity Pool
echo -e "${YELLOW}Checking Workload Identity Pool...${NC}"
POOL_EXISTS=$(gcloud iam workload-identity-pools describe github-pool \
    --location=global \
    --format="value(name)" 2>/dev/null || echo "")

if [[ -n "$POOL_EXISTS" ]]; then
    echo "✓ Workload Identity Pool 'github-pool' exists"
    
    # Get pool details
    POOL_DISPLAY_NAME=$(gcloud iam workload-identity-pools describe github-pool \
        --location=global \
        --format="value(displayName)" 2>/dev/null)
    echo "  Display Name: $POOL_DISPLAY_NAME"
else
    echo "✗ Workload Identity Pool 'github-pool' does NOT exist"
fi
echo ""

# Check Workload Identity Provider
echo -e "${YELLOW}Checking Workload Identity Provider...${NC}"
PROVIDER_EXISTS=$(gcloud iam workload-identity-pools providers describe github-provider \
    --workload-identity-pool=github-pool \
    --location=global \
    --format="value(name)" 2>/dev/null || echo "")

if [[ -n "$PROVIDER_EXISTS" ]]; then
    echo "✓ Workload Identity Provider 'github-provider' exists"
    
    # Get provider details
    echo ""
    echo -e "${BLUE}Provider Configuration:${NC}"
    
    # Get issuer URI
    ISSUER=$(gcloud iam workload-identity-pools providers describe github-provider \
        --workload-identity-pool=github-pool \
        --location=global \
        --format="value(oidc.issuerUri)" 2>/dev/null)
    echo "  Issuer URI: $ISSUER"
    
    # Get attribute condition
    CONDITION=$(gcloud iam workload-identity-pools providers describe github-provider \
        --workload-identity-pool=github-pool \
        --location=global \
        --format="value(attributeCondition)" 2>/dev/null)
    echo -e "  ${YELLOW}Attribute Condition:${NC}"
    echo "    $CONDITION"
    
    # Parse the repository from the condition
    if echo "$CONDITION" | grep -q "assertion.repository"; then
        # Extract repository name from the condition
        CONFIGURED_REPO=$(echo "$CONDITION" | sed -n "s/.*assertion\.repository[[:space:]]*==[[:space:]]*['\"]\\([^'\"]*\\)['\"].*/\\1/p")
        if [[ -n "$CONFIGURED_REPO" ]]; then
            echo -e "  ${BLUE}Configured Repository:${NC} $CONFIGURED_REPO"
            
            # Check for common issues
            if [[ "$CONFIGURED_REPO" =~ - ]]; then
                echo -e "    ${YELLOW}⚠ Warning: Repository contains hyphen (-). GitHub repos often use underscores (_)${NC}"
            fi
        fi
    fi
    
    # Get attribute mappings
    echo ""
    echo -e "${BLUE}Attribute Mappings:${NC}"
    gcloud iam workload-identity-pools providers describe github-provider \
        --workload-identity-pool=github-pool \
        --location=global \
        --format="value(attributeMapping)" 2>/dev/null | sed 's/;/\n  /g' | sed 's/^/  /'
else
    echo "✗ Workload Identity Provider 'github-provider' does NOT exist"
fi
echo ""

# Check Service Accounts
echo -e "${YELLOW}Checking Service Accounts...${NC}"
SA_NAME="terraform-${ENVIRONMENT}"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

SA_EXISTS=$(gcloud iam service-accounts describe "$SA_EMAIL" \
    --format="value(email)" 2>/dev/null || echo "")

if [[ -n "$SA_EXISTS" ]]; then
    echo "✓ Service Account exists: $SA_EMAIL"
    
    # Check IAM bindings
    echo ""
    echo -e "${BLUE}Service Account IAM Bindings:${NC}"
    
    # Get all bindings
    BINDINGS=$(gcloud iam service-accounts get-iam-policy "$SA_EMAIL" \
        --format=json 2>/dev/null || echo '{"bindings":[]}')
    
    # Check for workloadIdentityUser role
    WIF_BINDINGS=$(echo "$BINDINGS" | jq -r '.bindings[] | select(.role == "roles/iam.workloadIdentityUser") | .members[]' 2>/dev/null || echo "")
    
    if [[ -n "$WIF_BINDINGS" ]]; then
        echo "  Workload Identity User bindings:"
        echo "$WIF_BINDINGS" | while read -r member; do
            echo "    - $member"
            
            # Parse the member to extract repository
            if echo "$member" | grep -q "attribute.repository"; then
                BOUND_REPO=$(echo "$member" | sed -n 's/.*attribute\.repository\/\([^"]*\).*/\1/p')
                if [[ -n "$BOUND_REPO" ]]; then
                    echo -e "      ${BLUE}Repository:${NC} $BOUND_REPO"
                    
                    # Check for mismatches
                    if [[ -n "$CONFIGURED_REPO" ]] && [[ "$BOUND_REPO" != "$CONFIGURED_REPO" ]]; then
                        echo -e "      ${RED}⚠ MISMATCH: Binding repo ($BOUND_REPO) != Provider condition repo ($CONFIGURED_REPO)${NC}"
                    fi
                fi
            fi
        done
    else
        echo "  ✗ No workloadIdentityUser bindings found"
    fi
else
    echo "✗ Service Account does NOT exist: $SA_EMAIL"
fi
echo ""

# Check for resources service account
RESOURCES_SA="terraform-${ENVIRONMENT}-resources@${PROJECT_ID}.iam.gserviceaccount.com"
RESOURCES_SA_EXISTS=$(gcloud iam service-accounts describe "$RESOURCES_SA" \
    --format="value(email)" 2>/dev/null || echo "")

if [[ -n "$RESOURCES_SA_EXISTS" ]]; then
    echo "✓ Resources Service Account exists: $RESOURCES_SA"
    
    # Check IAM bindings for resources SA
    RESOURCES_BINDINGS=$(gcloud iam service-accounts get-iam-policy "$RESOURCES_SA" \
        --format=json 2>/dev/null | jq -r '.bindings[] | select(.role == "roles/iam.workloadIdentityUser") | .members[]' 2>/dev/null || echo "")
    
    if [[ -n "$RESOURCES_BINDINGS" ]]; then
        echo "  Workload Identity User bindings:"
        echo "$RESOURCES_BINDINGS" | while read -r member; do
            echo "    - $member"
        done
    fi
fi
echo ""

# Generate diagnostic summary
echo -e "${GREEN}=== Diagnostic Summary ===${NC}"
echo ""

# Check for common issues
ISSUES_FOUND=false

if [[ "$APIS_ENABLED" == "false" ]]; then
    echo -e "${RED}✗ ISSUE: Required APIs are not enabled${NC}"
    echo "  Fix: Run 'gcloud services enable iamcredentials.googleapis.com sts.googleapis.com'"
    ISSUES_FOUND=true
fi

if [[ -z "$POOL_EXISTS" ]]; then
    echo -e "${RED}✗ ISSUE: Workload Identity Pool does not exist${NC}"
    echo "  Fix: Run 'just setup-wif $ENVIRONMENT <github-org> <github-repo>'"
    ISSUES_FOUND=true
fi

if [[ -z "$PROVIDER_EXISTS" ]]; then
    echo -e "${RED}✗ ISSUE: Workload Identity Provider does not exist${NC}"
    echo "  Fix: Run 'just setup-wif $ENVIRONMENT <github-org> <github-repo>'"
    ISSUES_FOUND=true
fi

if [[ -z "$SA_EXISTS" ]]; then
    echo -e "${RED}✗ ISSUE: Service Account does not exist${NC}"
    echo "  Fix: Service account should be created by Terraform"
    ISSUES_FOUND=true
fi

if [[ -z "$WIF_BINDINGS" ]] && [[ -n "$SA_EXISTS" ]]; then
    echo -e "${RED}✗ ISSUE: Service Account has no workloadIdentityUser bindings${NC}"
    echo "  Fix: Run 'just setup-wif $ENVIRONMENT <github-org> <github-repo>'"
    ISSUES_FOUND=true
fi

if [[ -n "$CONFIGURED_REPO" ]] && [[ "$CONFIGURED_REPO" =~ - ]]; then
    echo -e "${YELLOW}⚠ WARNING: Repository in attribute condition contains hyphen${NC}"
    echo "  Current: $CONFIGURED_REPO"
    echo "  Check if your GitHub repo actually uses underscore instead"
    echo "  Fix: Run './scripts/fix-wif-attribute.sh -p $PROJECT_ID -e $ENVIRONMENT -o <github-org> -r <correct-repo-name>'"
fi

if [[ "$ISSUES_FOUND" == "false" ]]; then
    echo -e "${GREEN}✓ No obvious issues found${NC}"
    echo ""
    echo "If you're still having authentication issues:"
    echo "1. Verify the GitHub repository name matches exactly (check for - vs _)"
    echo "2. Ensure GitHub secrets are set correctly:"
    ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')
    echo "   - GCP_${ENV_UPPER}_PROJECT_NUMBER = $PROJECT_NUMBER"
    PREFIX="${PROJECT_ID%-*}"
    echo "   - GCP_PROJECT_PREFIX = $PREFIX"
    echo "3. Check the GitHub Actions logs for the exact error message"
    echo "4. Try re-running the WIF setup:"
    echo "   just setup-wif $ENVIRONMENT <github-org> <github-repo>"
fi

echo ""
echo -e "${BLUE}Full WIF Provider Path:${NC}"
echo "projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
echo ""
echo -e "${BLUE}Expected Service Account:${NC}"
echo "$SA_EMAIL"