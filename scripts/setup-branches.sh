#!/bin/bash
# Script to set up the initial branch structure for the MLOps Terraform project

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MLOps Terraform Branch Setup ===${NC}"
echo

# Function to check if branch exists locally
branch_exists_local() {
    git show-ref --verify --quiet refs/heads/"$1"
}

# Function to check if branch exists on remote
branch_exists_remote() {
    git ls-remote --heads origin "$1" | grep -q "$1"
}

# Function to create and push branch
create_branch() {
    local branch_name=$1
    local base_branch=$2
    
    echo -e "${YELLOW}Creating branch: $branch_name from $base_branch${NC}"
    
    # Check if branch already exists
    if branch_exists_local "$branch_name"; then
        echo -e "${GREEN}✓ Branch $branch_name already exists locally${NC}"
    else
        git checkout "$base_branch"
        git pull origin "$base_branch"
        git checkout -b "$branch_name"
        echo -e "${GREEN}✓ Created branch $branch_name locally${NC}"
    fi
    
    # Push to remote if it doesn't exist
    if branch_exists_remote "$branch_name"; then
        echo -e "${GREEN}✓ Branch $branch_name already exists on remote${NC}"
    else
        git push -u origin "$branch_name"
        echo -e "${GREEN}✓ Pushed branch $branch_name to remote${NC}"
    fi
}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Fetch latest from remote
echo -e "${BLUE}Fetching latest from remote...${NC}"
git fetch origin

# Ensure main branch exists and is up to date
echo -e "${BLUE}Setting up main branch (production)...${NC}"
if ! branch_exists_local "main"; then
    if branch_exists_remote "main"; then
        git checkout -b main origin/main
        echo -e "${GREEN}✓ Checked out main branch from remote${NC}"
    else
        echo -e "${RED}Error: main branch doesn't exist on remote${NC}"
        echo "Please ensure your repository has a main branch"
        exit 1
    fi
else
    git checkout main
    git pull origin main
    echo -e "${GREEN}✓ Main branch updated${NC}"
fi

# Create develop branch from main
echo
echo -e "${BLUE}Setting up develop branch (staging)...${NC}"
create_branch "develop" "main"

# Create initial readme for develop if it doesn't have unique content
git checkout develop
if ! grep -q "STAGING ENVIRONMENT" README.md 2>/dev/null; then
    echo -e "${YELLOW}Adding staging environment notice to develop branch...${NC}"
    
    # Create a temporary marker file
    cat > STAGING_NOTICE.md << 'EOF'
# Staging Environment Branch

This is the `develop` branch, which represents the **staging environment**.

## Important Notes

- This branch is automatically kept in sync with `main` (production)
- All feature branches should be created from this branch
- Changes are tested here before promoting to production

## Workflow

1. Create feature branches from `develop`: `git checkout -b dev/feature-name`
2. Merge feature branches back to `develop` for staging tests
3. Once tested, create PR from `develop` to `main` for production deployment
4. After merging to `main`, this branch is automatically updated

See [Branch Management Strategy](docs/BRANCH_MANAGEMENT_STRATEGY.md) for details.
EOF
    
    git add STAGING_NOTICE.md
    git commit -m "docs: Add staging environment notice for develop branch" || true
    git push origin develop || true
    echo -e "${GREEN}✓ Added staging notice to develop branch${NC}"
fi

# Provide summary
echo
echo -e "${GREEN}=== Branch Setup Complete ===${NC}"
echo
echo -e "${BLUE}Branch Structure:${NC}"
echo "  main    → Production environment"
echo "  develop → Staging environment"
echo "  dev/*   → Development features (to be created as needed)"
echo
echo -e "${BLUE}Current branch status:${NC}"
git branch -a | grep -E "^\*|main|develop" | head -5
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Configure branch protection rules in GitHub Settings"
echo "   See: docs/GITHUB_BRANCH_PROTECTION_SETUP.md"
echo
echo "2. Ensure GitHub Actions has proper permissions"
echo "   Settings → Actions → General → Workflow permissions"
echo
echo "3. Set up GitHub Secrets for each environment"
echo "   Run: just github-secrets add --all"
echo
echo "4. Create your first feature branch:"
echo "   git checkout develop"
echo "   git checkout -b dev/my-first-feature"
echo
echo -e "${GREEN}✓ Ready to start development!${NC}"

# Checkout develop as the default working branch
git checkout develop
echo
echo -e "${BLUE}You are now on the develop branch (staging environment)${NC}"