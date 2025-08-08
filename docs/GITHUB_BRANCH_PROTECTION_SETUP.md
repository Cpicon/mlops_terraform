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

### Bypass List (IMPORTANT for automated sync):
Add to bypass list:
- `github-actions[bot]` - Required for automated sync from main
- Repository administrators (optional)

**Note**: If `github-actions[bot]` doesn't appear in the search:
1. Run any GitHub Action first: `gh workflow run test-bot.yaml`
2. Or manually type `github-actions[bot]` and press Enter
3. The bot will be added even if not in suggestions

### 3. Configure GitHub Actions Bot Permissions

For the sync workflow to work properly, ensure:

1. **GitHub Actions has write permissions:**
   - Go to **Settings → Actions → General**
   - Under "Workflow permissions", select:
     - ✅ Read and write permissions
     - ✅ Allow GitHub Actions to create and approve pull requests

2. **Create a Personal Access Token (PAT) for advanced operations (if needed):**
   - Go to **Settings → Developer settings → Personal access tokens → Tokens (classic)**
   - Generate new token with scopes:
     - `repo` (Full control of private repositories)
     - `workflow` (Update GitHub Action workflows)
   
   Then add as repository secret:
   - Go to **Settings → Secrets and variables → Actions**
   - Add secret named `SYNC_TOKEN` with the PAT value

## Setting Up Automated Sync

### 1. Enable the Sync Workflow

The sync workflow (`.github/workflows/sync-develop.yaml`) is automatically triggered when:
- Commits are pushed to `main` branch
- Manual workflow dispatch

No additional setup needed if using `GITHUB_TOKEN`.

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
1. Check GitHub Actions permissions (Settings → Actions → General)
2. Ensure "Read and write permissions" is selected
3. If using PAT, verify token hasn't expired

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

- [Branch Management Strategy](./BRANCH_MANAGEMENT_STRATEGY.md)
- [Terraform Tutorial](../TERRAFORM_TUTORIAL.md)
- [GitHub Actions Workflows](../.github/workflows/)
- [GitHub Secrets Setup](./GITHUB_SECRETS_SETUP.md)