#!/bin/bash
# Script to set GitHub Secrets for environment-specific project numbers
# This is required for the distributed WIF architecture where each environment has its own WIF

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Set GitHub Secrets for environment-specific GCP project numbers.
Required for distributed Workload Identity Federation (WIF) architecture.

Options:
    -r, --repo OWNER/REPO    GitHub repository (e.g., "myorg/myrepo")
                             If not specified, will try to detect from current git repo
    -h, --help               Show this help message

This script will:
1. Read project IDs from .env-mlops
2. Get the project number for each environment
3. Create GitHub secrets:
   - GCP_DEV_PROJECT_NUMBER
   - GCP_STAGE_PROJECT_NUMBER
   - GCP_PROD_PROJECT_NUMBER

Prerequisites:
    - .env-mlops file must exist (run: just setup-vars)
    - gcloud CLI must be installed and authenticated
    - GitHub CLI (gh) must be installed and authenticated
    - You must have permissions to read GCP projects
    - You must have permissions to create GitHub secrets

Examples:
    # Auto-detect repository
    $0

    # Specify repository
    $0 -r myorg/myrepo

Note: This is different from GCP_PROJECT_NUMBER (singular) which was used
      for centralized WIF. These environment-specific numbers are used for
      distributed WIF where each environment has its own WIF setup.
EOF
    exit 0
}

# Default values
REPO=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Try to detect repository from git if not specified
if [[ -z "$REPO" ]]; then
    if git remote get-url origin >/dev/null 2>&1; then
        REPO=$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
        echo -e "${YELLOW}Detected repository from git: $REPO${NC}"
    else
        echo -e "${RED}Error: Could not detect repository. Please specify with -r option.${NC}"
        exit 1
    fi
fi

# Check if .env-mlops exists
if [ ! -f .env-mlops ]; then
    echo -e "${RED}Error: .env-mlops file not found.${NC}"
    echo "Please run: just setup-vars"
    exit 1
fi

# Load environment variables
source .env-mlops

# Check if gh CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI is not authenticated.${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed.${NC}"
    echo "Install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}Error: gcloud is not authenticated.${NC}"
    echo "Run: gcloud auth login"
    exit 1
fi

echo -e "${GREEN}=== GitHub Project Number Secrets Setup ===${NC}"
echo -e "Repository: ${BLUE}$REPO${NC}"
echo ""

# Function to get project number
get_project_number() {
    local project_id="$1"
    local project_number
    
    project_number=$(gcloud projects describe "$project_id" --format="value(projectNumber)" 2>/dev/null)
    
    if [ -z "$project_number" ]; then
        echo ""
        return 1
    else
        echo "$project_number"
        return 0
    fi
}

# Function to set secret
set_secret() {
    local secret_name="$1"
    local secret_value="$2"
    
    echo -e "  Setting secret: ${BLUE}$secret_name${NC}"
    if echo "$secret_value" | gh secret set "$secret_name" -R "$REPO"; then
        echo -e "  ${GREEN}✓${NC} Secret set successfully"
        return 0
    else
        echo -e "  ${RED}✗${NC} Failed to set secret"
        return 1
    fi
}

# Track success/failure
FAILED_ENVS=()

# Process each environment
for env in dev stage prod; do
    echo -e "\n${GREEN}Processing $env environment...${NC}"
    
    # Get project ID from environment variables
    case $env in
        dev)
            PROJECT_ID="$DEV_PROJECT"
            SECRET_NAME="GCP_DEV_PROJECT_NUMBER"
            ;;
        stage)
            PROJECT_ID="$STAGE_PROJECT"
            SECRET_NAME="GCP_STAGE_PROJECT_NUMBER"
            ;;
        prod)
            PROJECT_ID="$PROD_PROJECT"
            SECRET_NAME="GCP_PROD_PROJECT_NUMBER"
            ;;
    esac
    
    echo -e "  Project ID: ${BLUE}$PROJECT_ID${NC}"
    
    # Get project number
    echo -e "  Getting project number..."
    PROJECT_NUMBER=$(get_project_number "$PROJECT_ID")
    
    if [ -z "$PROJECT_NUMBER" ]; then
        echo -e "  ${RED}✗${NC} Failed to get project number for $PROJECT_ID"
        echo -e "  ${YELLOW}Possible reasons:${NC}"
        echo "    - Project doesn't exist"
        echo "    - Insufficient permissions"
        echo "    - Project ID is incorrect in .env-mlops"
        FAILED_ENVS+=("$env")
        continue
    fi
    
    echo -e "  Project Number: ${BLUE}$PROJECT_NUMBER${NC}"
    
    # Set the GitHub secret
    if set_secret "$SECRET_NAME" "$PROJECT_NUMBER"; then
        echo -e "  ${GREEN}✓${NC} $env environment configured successfully"
    else
        FAILED_ENVS+=("$env")
    fi
done

# Also set the project prefix if not already set
echo -e "\n${GREEN}Setting project prefix...${NC}"
PROJECT_PREFIX=$(echo "$DEV_PROJECT" | sed 's/-dev$//')
echo -e "  Project Prefix: ${BLUE}$PROJECT_PREFIX${NC}"

if gh secret list -R "$REPO" | grep -q "GCP_PROJECT_PREFIX"; then
    echo -e "  ${YELLOW}ℹ${NC} GCP_PROJECT_PREFIX already exists"
else
    if set_secret "GCP_PROJECT_PREFIX" "$PROJECT_PREFIX"; then
        echo -e "  ${GREEN}✓${NC} GCP_PROJECT_PREFIX set successfully"
    else
        echo -e "  ${RED}✗${NC} Failed to set GCP_PROJECT_PREFIX"
    fi
fi

# Summary
echo ""
echo -e "${GREEN}=== Setup Summary ===${NC}"
echo ""

if [ ${#FAILED_ENVS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All project number secrets configured successfully!${NC}"
    echo ""
    echo "The following secrets have been set:"
    echo "  - GCP_DEV_PROJECT_NUMBER"
    echo "  - GCP_STAGE_PROJECT_NUMBER"
    echo "  - GCP_PROD_PROJECT_NUMBER"
    echo "  - GCP_PROJECT_PREFIX (if not already set)"
else
    echo -e "${YELLOW}⚠ Setup completed with some failures:${NC}"
    for env in "${FAILED_ENVS[@]}"; do
        echo -e "  ${RED}✗${NC} $env environment failed"
    done
    echo ""
    echo "Please fix the issues and re-run this script."
    exit 1
fi

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Verify WIF is set up in each environment:"
echo "   just verify-wif dev"
echo "   just verify-wif stage"
echo "   just verify-wif prod"
echo ""
echo "2. If WIF is not set up, run:"
echo "   just setup-wif dev <github-org> <github-repo>"
echo "   just setup-wif stage <github-org> <github-repo>"
echo "   just setup-wif prod <github-org> <github-repo>"
echo ""
echo "3. Test the GitHub Actions workflow with a PR"