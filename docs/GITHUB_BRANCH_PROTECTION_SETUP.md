# GitHub Branch Protection Rules Setup

This guide provides step-by-step instructions for setting up branch protection rules to support our branch management strategy.

## Prerequisites

- Admin access to the GitHub repository
- Understanding of the [Branch Management Strategy](./BRANCH_MANAGEMENT_STRATEGY.md)

## Branch Protection Configuration

### 1. Protect the Main Branch (Production)

Navigate to: **Settings → Branches → Add rule**

**Branch name pattern:** `main`

**Protection Settings:**

✅ **Require a pull request before merging**
- ✅ Require approvals: `2`
- ✅ Dismiss stale pull request approvals when new commits are pushed
- ✅ Require review from CODEOWNERS
- ✅ Require approval of the most recent reviewable push

✅ **Require status checks to pass before merging**
- ✅ Require branches to be up to date before merging
- **Required status checks:**
  - `terraform-plan`
  - `terraform-apply` (if exists)

✅ **Require conversation resolution before merging**

✅ **Require signed commits** (optional but recommended)

✅ **Include administrators** (enforce rules for admins too)

⚠️ **Do not allow bypassing the above settings**

✅ **Restrict who can push to matching branches**
- Add specific users or teams who can merge to production

❌ **Do not allow force pushes**
❌ **Do not allow deletions**

### 2. Protect the Develop Branch (Staging)

Navigate to: **Settings → Branches → Add rule**

**Branch name pattern:** `develop`

**Protection Settings:**

✅ **Require a pull request before merging**
- ✅ Require approvals: `1`
- ✅ Dismiss stale pull request approvals when new commits are pushed
- ❌ Do not require review from CODEOWNERS (more flexible for staging)

✅ **Require status checks to pass before merging**
- ✅ Require branches to be up to date before merging
- **Required status checks:**
  - `terraform-plan`

✅ **Require conversation resolution before merging**

❌ **Do not include administrators** (allows automated sync from main)

✅ **Block force pushes**

❌ **Do not allow deletions**

### Bypass List Configuration:

**IMPORTANT**: GitHub Actions bot (`github-actions[bot]`) cannot be added to branch protection bypass lists. This is a known GitHub limitation. Use the PAT solution below instead.

### 3. Configure Automated Workflow Permissions

Since `github-actions[bot]` cannot be added to bypass lists, you must use a Personal Access Token (PAT) for automated workflows to push to protected branches.

#### Step 1: Create a Personal Access Token (PAT)

1. Go to your GitHub **Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **"Generate new token (classic)"**
3. Give it a descriptive name: `mlops-terraform-sync`
4. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
5. Generate and copy the token

#### Step 2: Add PAT as Repository Secret

1. Go to your repository **Settings → Secrets and variables → Actions**
2. Click **"New repository secret"**
3. Name: `SYNC_TOKEN`
4. Value: Paste your PAT
5. Click **"Add secret"**

#### Step 3: Add Yourself to Bypass List

Since the PAT represents your account:
1. Go to **Settings → Branches → Edit rule** for `develop`
2. In the **"Restrict who can push to matching branches"** or **"Bypass list"** section:
   - Click **"Add"** or **"Add bypass"**
   - Search for and add your GitHub username
   - This allows workflows using your PAT to bypass protection

#### Step 4: Verify Workflow Configuration

The sync workflow (`.github/workflows/sync-develop.yaml`) should use the SYNC_TOKEN:
```yaml
- name: Checkout repository
  uses: actions/checkout@v4
  with:
    fetch-depth: 0
    token: ${{ secrets.SYNC_TOKEN }}  # Uses PAT instead of GITHUB_TOKEN
```

#### Alternative: GitHub Actions Write Permissions (Limited)

If you don't need full branch protection bypass:
1. Go to **Settings → Actions → General**
2. Under "Workflow permissions", select:
   - ✅ Read and write permissions
   - ✅ Allow GitHub Actions to create and approve pull requests
3. Note: This won't bypass branch protection but allows basic operations

## Setting Up Automated Sync

### 1. Enable the Sync Workflow

The sync workflow (`.github/workflows/sync-develop.yaml`) is automatically triggered when:
- Commits are pushed to `main` branch
- Manual workflow dispatch

**Important**: The workflow requires `SYNC_TOKEN` to bypass branch protection. Without it, the sync will fail on protected branches.

### 2. Configure Notifications (Optional)

#### Slack Notifications
1. Create a Slack Webhook URL in your Slack workspace
2. Add as repository secret `SLACK_WEBHOOK`
3. The workflow will automatically send notifications

#### Email Notifications
GitHub automatically sends emails for:
- Failed workflows
- Created issues (for merge conflicts)

## Branch Naming Conventions

Configure branch naming patterns to auto-deploy to correct environments:

| Branch Pattern | Environment | Auto-Deploy | Protected |
|---------------|-------------|-------------|-----------|
| `main` | Production | Yes, on merge | Yes |
| `develop` | Staging | Yes, on merge | Yes |
| `dev/*` | Development | Yes, on push | No |
| `feature/*` | None | No | No |
| `hotfix/*` | None | No | No |

## Verification Checklist

After setting up branch protection:

### Test Main Branch Protection
```bash
# This should fail (direct push to main)
git checkout main
echo "test" > test.txt
git add . && git commit -m "test"
git push origin main
# Expected: Rejected due to branch protection
```

### Test Develop Branch Protection
```bash
# This should fail (direct push to develop)
git checkout develop
echo "test" > test.txt
git add . && git commit -m "test"
git push origin develop
# Expected: Rejected due to branch protection
```

### Test Feature Branch Flow
```bash
# This should succeed
git checkout develop
git checkout -b dev/test-feature
echo "test" > test.txt
git add . && git commit -m "test"
git push origin dev/test-feature
# Expected: Success, triggers dev deployment
```

### Test Automated Sync
1. Merge a PR from `dev/*` to `develop`
2. Merge a PR from `develop` to `main`
3. Check that sync workflow runs automatically
4. Verify `develop` contains all changes from `main`

## Troubleshooting

### Issue: Sync workflow fails with permission denied

**Solution:**
1. Verify `SYNC_TOKEN` secret is properly configured
2. Check that your user account (PAT owner) is in the bypass list for the `develop` branch
3. Ensure PAT hasn't expired and has correct scopes (`repo` and `workflow`)
4. Verify the workflow is using `token: ${{ secrets.SYNC_TOKEN }}` in checkout step

### Issue: Cannot merge to protected branch

**Solution:**
1. Verify you're in the allowed users/teams list
2. Ensure all required status checks are passing
3. Check that PR has required approvals

### Issue: Develop branch diverges from main

**Solution:**
1. Check if sync workflow is running after main updates
2. Look for open issues about merge conflicts
3. Manually sync if needed:
```bash
git checkout develop
git merge main
git push origin develop
```

## Best Practices

1. **Review protection rules monthly** to ensure they still meet team needs

2. **Document exceptions** when protection rules are temporarily modified

3. **Test after changes** to protection rules to ensure workflows still function

4. **Monitor sync failures** and address conflicts promptly

5. **Keep protection rules in sync** with CI/CD pipeline requirements

## Related Documentation

- [Branch Protection with Automation](./BRANCH_PROTECTION_WITH_AUTOMATION.md)
- [Branch Management Strategy](./BRANCH_MANAGEMENT_STRATEGY.md)
- [Terraform Tutorial](../TERRAFORM_TUTORIAL.md)
- [GitHub Actions Workflows](../.github/workflows/)
- [GitHub Secrets Setup](./GITHUB_SECRETS_SETUP.md)
- [GitHub Community Discussion on Bot Limitations](https://github.com/orgs/community/discussions/13836)