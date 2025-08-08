# Branch Protection with Automated Workflows

## The Challenge

GitHub Actions bot (`github-actions[bot]`) cannot be added to branch protection bypass lists. This is a known GitHub limitation that prevents automated workflows from pushing to protected branches.

## Solution: Use Personal Access Token (PAT)

### Step 1: Create a Personal Access Token

1. Go to your GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name: `mlops-terraform-automation`
4. Select scopes:
   - `repo` (full control of private repositories)
   - `workflow` (update GitHub Action workflows)
5. Generate and copy the token

### Step 2: Add PAT as Repository Secret

1. Go to your repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `SYNC_TOKEN` (or any descriptive name)
4. Value: Paste your PAT
5. Click "Add secret"

### Step 3: Update Sync Workflow to Use PAT

The workflow needs to be updated to use the PAT instead of the default GITHUB_TOKEN:

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
    token: ${{ secrets.SYNC_TOKEN }}  # Use PAT instead of GITHUB_TOKEN
```

### Step 4: Configure Branch Protection

1. Go to Settings → Branches → Edit rule for `develop`
2. Add yourself (the PAT owner) to the bypass list
3. This allows the workflow (using your PAT) to push to the protected branch

## Alternative Solutions

### Option 2: Create a GitHub App

Create a custom GitHub App that can be added to bypass lists:
- More complex setup
- Better for organization-wide automation
- Provides fine-grained permissions

### Option 3: Use Merge Queue

GitHub's merge queue can handle automatic merging without needing bypass permissions:
- Enable merge queue in branch protection settings
- Workflows can add PRs to the queue
- Queue handles the actual merging

### Option 4: Disable Protection Temporarily

Use GitHub API to temporarily disable protection (NOT RECOMMENDED):
- Security risk
- Complex implementation
- Race conditions possible

## Current Implementation Status

Currently, the sync-develop workflow will fail if branch protection is enabled without bypass permissions. You need to either:
1. Implement the PAT solution above
2. Keep branch protection disabled for automated pushes
3. Manually sync branches when needed

## References

- [GitHub Community Discussion #13836](https://github.com/orgs/community/discussions/13836)
- [GitHub Actions: Using tokens](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)