#!/bin/bash
# Script to grant WIF principals permission to impersonate service accounts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ ! -f .env-mlops ]; then
    echo -e "${RED}Error: .env-mlops file not found${NC}"
    echo "Please run: just setup-vars"
    exit 1
fi

source .env-mlops

echo -e "${GREEN}=== Granting WIF Impersonation Permissions ===${NC}"
echo "This will grant GitHub Actions the ability to impersonate service accounts"
echo ""

# Get repository information
GITHUB_REPO=$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' || echo "")
if [[ -z "$GITHUB_REPO" ]]; then
    echo -e "${RED}Error: Could not detect GitHub repository${NC}"
    echo "Please ensure you're in a git repository with a GitHub remote"
    exit 1
fi

echo "Repository: $GITHUB_REPO"
echo ""

# Process each environment
for env in dev stage prod; do
    case $env in
        dev) PROJECT=$DEV_PROJECT; PROJECT_NUM=4275271155 ;;
        stage) PROJECT=$STAGE_PROJECT; PROJECT_NUM=729631533282 ;;
        prod) PROJECT=$PROD_PROJECT; PROJECT_NUM=391673587007 ;;
    esac
    
    echo -e "${BLUE}Processing $env environment...${NC}"
    echo "Project: $PROJECT"
    
    # Set project context
    gcloud config set project "$PROJECT" --quiet 2>/dev/null
    
    # Define the WIF principal
    MEMBER="principalSet://iam.googleapis.com/projects/${PROJECT_NUM}/locations/global/workloadIdentityPools/github-pool/attribute.repository/${GITHUB_REPO}"
    
    # Grant permission to impersonate the state management SA
    SA_EMAIL="terraform-${env}@${PROJECT}.iam.gserviceaccount.com"
    echo "Granting serviceAccountTokenCreator on $SA_EMAIL..."
    
    if gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
        --member="$MEMBER" \
        --role="roles/iam.serviceAccountTokenCreator" \
        --project="$PROJECT" \
        --quiet 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Granted for state management SA"
    else
        echo -e "  ${YELLOW}⚠${NC} Already granted or error (continuing...)"
    fi
    
    # Grant permission to impersonate the resources SA
    RESOURCES_SA="terraform-${env}-resources@${PROJECT}.iam.gserviceaccount.com"
    if gcloud iam service-accounts describe "$RESOURCES_SA" --project="$PROJECT" &>/dev/null; then
        echo "Granting serviceAccountTokenCreator on $RESOURCES_SA..."
        
        if gcloud iam service-accounts add-iam-policy-binding "$RESOURCES_SA" \
            --member="$MEMBER" \
            --role="roles/iam.serviceAccountTokenCreator" \
            --project="$PROJECT" \
            --quiet 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Granted for resources SA"
        else
            echo -e "  ${YELLOW}⚠${NC} Already granted or error (continuing...)"
        fi
    fi
    
    echo ""
done

echo -e "${GREEN}=== Complete ===${NC}"
echo ""
echo "GitHub Actions can now impersonate service accounts in all environments."
echo "The WIF authentication should now work correctly in your workflows."
echo ""
echo "If you still encounter issues, verify that:"
echo "1. WIF providers are ACTIVE (run: just verify-wif dev/stage/prod)"
echo "2. GitHub secrets are set (run: gh secret list | grep GCP)"
echo "3. Repository name matches: $GITHUB_REPO"