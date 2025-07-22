# GitHub Actions Setup Guide

This guide walks through setting up GitHub Actions for automated Terraform deployments.

📊 **Visual GitFlow diagram available in [GITFLOW_PROCESS.md](./GITFLOW_PROCESS.md)**

## Quick Setup

### 1. Configure Workload Identity Federation

```bash
# For each environment
just setup-wif dev YOUR_GITHUB_ORG YOUR_GITHUB_REPO
just setup-wif stage YOUR_GITHUB_ORG YOUR_GITHUB_REPO  
just setup-wif prod YOUR_GITHUB_ORG YOUR_GITHUB_REPO

# Verify setup
just verify-wif dev
just verify-wif stage
just verify-wif prod
```

### 2. Add GitHub Secrets

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Add these repository secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `GCP_PROJECT_NUMBER` | Your GCP project number | `123456789012` |
| `GCP_PROJECT_PREFIX` | Project name prefix | `mycompany-mlops` |

To get these values:
```bash
# Get project number
gcloud projects describe YOUR_PROJECT_ID --format="value(projectNumber)"

# Project prefix is the part before -dev/-stage/-prod
# Example: mycompany-mlops-dev → prefix is mycompany-mlops
```

### 3. Configure Branch Protection (Recommended)

For `main` branch:
1. Go to Settings → Branches
2. Add rule for `main`
3. Enable:
   - Require a pull request before merging
   - Require status checks to pass (select `terraform-plan`)
   - Restrict who can push to matching branches

For `develop` branch:
1. Add rule for `develop`
2. Same settings as main

## Workflow Behavior

| Action | Branch/Target | Environment | Behavior |
|--------|---------------|-------------|----------|
| PR merged | → main | prod | Auto plan & apply |
| PR merged | → develop | stage | Auto plan & apply |
| Push | dev/* branches | dev | Auto plan & apply |
| PR opened/updated | → main | prod | Plan only (shows prod changes) |
| PR opened/updated | → develop | stage | Plan only (shows stage changes) |
| Manual | - | dev | Plan & apply on demand |
| Schedule | - | prod | Daily at 1 AM UTC |

**Important:** Direct pushes to `main` or `develop` will NOT trigger deployments. You must create and merge a PR.

## Testing the Setup

### 1. Test Manual Deployment (Dev)

1. Go to Actions tab
2. Select "Terraform Apply"
3. Click "Run workflow"
4. Select environment: `dev`
5. Run workflow

### 2. Test Dev Branch Deployment

1. Create a branch: `git checkout -b dev/test-feature`
2. Make a change and push
3. Check Actions tab - should auto-deploy to dev

### 3. Test Stage Deployment

1. Create a branch from develop
2. Make a small change (e.g., add a label)
3. Create PR to develop
4. Check that plan runs and comments on PR
5. Merge PR to see auto-apply to stage

### 4. Test Production Deployment

1. Create PR from develop to main
2. Review the plan comment
3. Get approval and merge
4. Check auto-apply to prod

## Troubleshooting

### WIF Authentication Issues

```bash
# Check WIF setup
just verify-wif <env>

# Common issues:
# - Wrong project number in secrets
# - Service account doesn't exist
# - WIF pool/provider misconfigured
```

### Workflow Not Triggering

Check:
- Branch protection rules
- GitHub Actions is enabled for the repo
- Workflow file is in `.github/workflows/`
- YAML syntax is valid

### Plan/Apply Failures

1. Check the workflow logs in Actions tab
2. Common issues:
   - API not enabled
   - Service account missing permissions
   - State lock (another operation running)
   - Invalid Terraform syntax

## Security Best Practices

1. **Never commit secrets**: All sensitive data in GitHub Secrets
2. **Use WIF**: No service account keys needed
3. **Limit permissions**: Service accounts have minimal required roles
4. **Review plans**: Even with auto-apply, review plan outputs
5. **Protect branches**: Enforce PR reviews for main/develop

## Next Steps

1. Test the workflow with a simple change
2. Set up notifications for workflow failures
3. Add additional status checks as needed
4. Document your team's deployment process