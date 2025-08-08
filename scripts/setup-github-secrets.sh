#!/bin/bash
# Script to set GitHub Secrets from terraform.tfvars files
# This script reads your local terraform.tfvars files and creates corresponding GitHub secrets

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
REPO=""
ENVIRONMENTS=("dev" "stage" "prod")

# Function to display usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Set GitHub Secrets from terraform.tfvars files for all environments.

Options:
    -r, --repo OWNER/REPO    GitHub repository (e.g., "myorg/myrepo")
                             If not specified, will try to detect from current git repo
    -e, --env ENV            Process only specific environment (dev, stage, or prod)
                             Default: all environments
    -d, --dry-run            Show what would be created without actually creating secrets
    -h, --help               Show this help message

Examples:
    # Set secrets for all environments
    $0 -r myorg/myrepo

    # Set secrets for dev environment only
    $0 -r myorg/myrepo -e dev

    # Dry run to see what would be created
    $0 -r myorg/myrepo --dry-run

Prerequisites:
    - GitHub CLI (gh) must be installed and authenticated
    - terraform.tfvars files must exist in environments/{dev,stage,prod}/ directories
    - You must have permission to create secrets in the repository

Note: Lists in terraform.tfvars will be converted to JSON format for GitHub Secrets.
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -e|--env)
            ENVIRONMENTS=("$2")
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
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

echo -e "${GREEN}=== GitHub Secrets Setup ===${NC}"
echo -e "Repository: ${BLUE}$REPO${NC}"
echo -e "Dry Run: ${BLUE}$DRY_RUN${NC}"
echo ""

# Function to parse a terraform.tfvars file and extract value
parse_tfvars_value() {
    local file="$1"
    local key="$2"
    
    # Read the file and extract the value for the key
    # This handles simple values, strings, and lists
    awk -v key="$key" '
    BEGIN { in_list = 0; list_content = ""; found = 0 }
    
    # Match key = value or key= value
    $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
        found = 1
        # Remove everything before =
        sub(/^[^=]*=[[:space:]]*/, "")
        
        # Check if this is a list (starts with [)
        if (/^\[/) {
            in_list = 1
            list_content = $0
            # Check if list ends on same line
            if (/\]/) {
                print list_content
                in_list = 0
                exit
            }
        } else {
            # Simple value - remove quotes if present
            gsub(/^"|"$/, "")
            print $0
            exit
        }
    }
    
    # Continue reading list content
    in_list == 1 {
        if (found == 1 && NR > 1) {
            list_content = list_content " " $0
            if (/\]/) {
                print list_content
                in_list = 0
                exit
            }
        }
    }
    ' "$file"
}

# Function to convert HCL list to JSON format
hcl_list_to_json() {
    local hcl_list="$1"
    # Convert HCL list format to JSON
    # [  "a", "b"  ] -> ["a","b"]
    echo "$hcl_list" | sed 's/\[[:space:]*/[/g' | sed 's/[:space:]*\]/]/g' | sed 's/,[:space:]*/,/g'
}

# Function to create or update a secret
set_secret() {
    local secret_name="$1"
    local secret_value="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "  ${YELLOW}[DRY RUN]${NC} Would set secret: ${BLUE}$secret_name${NC}"
        echo -e "            Value: $secret_value"
    else
        echo -e "  Setting secret: ${BLUE}$secret_name${NC}"
        echo "$secret_value" | gh secret set "$secret_name" -R "$REPO"
        echo -e "  ${GREEN}✓${NC} Secret set successfully"
    fi
}

# Process each environment
for env in "${ENVIRONMENTS[@]}"; do
    echo -e "\n${GREEN}Processing $env environment...${NC}"
    
    tfvars_file="environments/$env/terraform.tfvars"
    
    # Check if tfvars file exists
    if [[ ! -f "$tfvars_file" ]]; then
        echo -e "  ${YELLOW}Warning: $tfvars_file not found. Skipping $env environment.${NC}"
        continue
    fi
    
    echo -e "  Reading from: ${BLUE}$tfvars_file${NC}"
    
    # GitHub automatically converts secret names to uppercase
    # So we use uppercase environment names to match what GitHub expects
    ENV_UPPER=$(echo "$env" | tr '[:lower:]' '[:upper:]')
    
    # List of variables to extract
    variables=(
        "project_id"
        "region"
        "zone"
        "dataset_owners"
        "dataset_writers"
        "dataset_readers"
        "ml_team_group"
        "analysts_group"
    )
    
    # Process each variable
    for var in "${variables[@]}"; do
        value=$(parse_tfvars_value "$tfvars_file" "$var")
        
        if [[ -n "$value" ]]; then
            # Determine if this is a list
            if [[ "$value" == \[* ]]; then
                # Convert HCL list to JSON format
                json_value=$(hcl_list_to_json "$value")
                # Use uppercase environment name (GitHub converts to uppercase anyway)
                secret_name="TF_VAR_${ENV_UPPER}_$(echo "$var" | tr '[:lower:]' '[:upper:]')"
                set_secret "$secret_name" "$json_value"
            else
                # Simple string value
                # Use uppercase environment name (GitHub converts to uppercase anyway)
                secret_name="TF_VAR_${ENV_UPPER}_$(echo "$var" | tr '[:lower:]' '[:upper:]')"
                set_secret "$secret_name" "$value"
            fi
        else
            echo -e "  ${YELLOW}Skipping $var (not found or empty)${NC}"
        fi
    done
done

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}=== Dry run complete ===${NC}"
    echo "No secrets were actually created. Remove --dry-run to create them."
else
    echo -e "${GREEN}=== Setup complete ===${NC}"
    echo "GitHub Secrets have been created/updated for the repository."
fi

echo ""
echo -e "${BLUE}Created/Updated secrets for GitHub Actions:${NC}"
for env in "${ENVIRONMENTS[@]}"; do
    ENV_UPPER=$(echo "$env" | tr '[:lower:]' '[:upper:]')
    echo -e "\n  ${env} environment (stored as uppercase):"
    echo "    - TF_VAR_${ENV_UPPER}_PROJECT_ID"
    echo "    - TF_VAR_${ENV_UPPER}_REGION"
    echo "    - TF_VAR_${ENV_UPPER}_ZONE"
    echo "    - TF_VAR_${ENV_UPPER}_DATASET_OWNERS (JSON array, optional)"
    echo "    - TF_VAR_${ENV_UPPER}_DATASET_WRITERS (JSON array, optional)"
    echo "    - TF_VAR_${ENV_UPPER}_DATASET_READERS (JSON array, optional)"
    echo "    - TF_VAR_${ENV_UPPER}_ML_TEAM_GROUP (optional)"
    echo "    - TF_VAR_${ENV_UPPER}_ANALYSTS_GROUP (optional)"
done

echo ""
echo -e "${YELLOW}Note:${NC} Don't forget to also set these repository secrets:"
echo "  - GCP_PROJECT_NUMBER (your GCP project number)"
echo "  - GCP_PROJECT_PREFIX (e.g., 'mycompany-mlops')"