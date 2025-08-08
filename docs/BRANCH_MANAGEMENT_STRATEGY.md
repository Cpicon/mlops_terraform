# Branch Management Strategy

This document outlines our Git branching strategy for managing infrastructure across development, staging, and production environments.

## Branch Overview

```
main (production)
  ↑
develop (staging) - always contains everything from main + staging features
  ↑
dev/* (development) - feature branches
```

## Core Branches

### 1. `main` Branch (Production)
- **Purpose**: Represents production-ready infrastructure
- **Deployment**: Automatically deploys to production environment
- **Protection**: Protected branch with strict merge requirements
- **Merges from**: `develop` branch only (after testing in staging)

### 2. `develop` Branch (Staging)
- **Purpose**: Integration branch for staging environment
- **Deployment**: Automatically deploys to staging environment
- **Protection**: Protected branch with merge requirements
- **Merges from**: `dev/*` feature branches
- **Syncs with**: Automatically rebased/merged with `main` after production deployments

### 3. `dev/*` Branches (Development)
- **Purpose**: Feature development and testing
- **Deployment**: Automatically deploys to development environment on push
- **Naming**: `dev/feature-name` or `dev/ticket-number`
- **Lifecycle**: Created from `develop`, merged back to `develop`, then deleted

## Workflow

### 1. Feature Development Flow
```bash
# 1. Start from develop branch
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b dev/my-feature

# 3. Make changes and push
git add .
git commit -m "Add my feature"
git push origin dev/my-feature

# 4. Create PR to develop
# After review and approval, merge to develop
```

### 2. Staging to Production Flow
```bash
# 1. Ensure develop is tested in staging
# 2. Create PR from develop to main
# 3. After review and approval, merge to main
# 4. Develop is automatically synced with main (see below)
```

### 3. Keeping Develop in Sync with Main

The `develop` branch is automatically kept in sync with `main` through our sync workflow:

#### Automatic Sync Triggers
- **Any push to main branch** - Including:
  - PR merges from develop to main
  - Direct hotfix pushes (emergency fixes)
  - Revert commits
  - Any other changes to production

#### How It Works
The GitHub Action automatically merges `main` back into `develop` after any change to main, ensuring develop always contains all production code plus staging features.

## Branch Protection Rules

### Main Branch Protection
```yaml
Settings → Branches → Add rule
- Branch name pattern: main
- Require pull request reviews: ✓
  - Required approving reviews: 2
  - Dismiss stale pull request approvals: ✓
- Require status checks to pass: ✓
  - terraform-plan
  - terraform-validate
- Require branches to be up to date: ✓
- Include administrators: ✓
- Restrict who can push: ✓
  - Only allow specific users/teams
```

### Develop Branch Protection
```yaml
Settings → Branches → Add rule
- Branch name pattern: develop
- Require pull request reviews: ✓
  - Required approving reviews: 1
- Require status checks to pass: ✓
  - terraform-plan
  - terraform-validate
- Include administrators: ✗ (allow sync from main)
```

## GitHub Actions Configuration

### Current Environment Mapping
- **main** branch → Production environment
- **develop** branch → Staging environment  
- **dev/*** branches → Development environment

### Automated Sync Workflow

The `.github/workflows/sync-develop.yaml` workflow automatically keeps `develop` in sync with `main` after production deployments.

## Best Practices

### 1. Never Delete Long-Lived Branches
- `main` and `develop` are permanent branches
- Only `dev/*` feature branches should be deleted after merge

### 2. Always Start Features from Develop
```bash
git checkout develop
git pull origin develop
git checkout -b dev/new-feature
```

### 3. Regular Sync Checks
```bash
# Check if develop has all commits from main
git checkout develop
git pull origin develop
git pull origin main --dry-run
```

### 4. Commit Message Standards
- **Features**: `feat: Add new capability`
- **Fixes**: `fix: Resolve issue with...`
- **Infrastructure**: `infra: Update terraform modules`
- **Documentation**: `docs: Update README`

### 5. Pull Request Standards

#### PR to Develop (Staging)
- Title: `[STAGE] Brief description`
- Description should include:
  - What changed
  - Why it changed
  - Testing performed
  - Rollback plan

#### PR to Main (Production)
- Title: `[PROD] Brief description`
- Description should include:
  - What was tested in staging
  - Impact analysis
  - Rollback plan
  - Post-deployment verification steps

## Handling Conflicts

If conflicts arise when syncing `develop` with `main`:

1. **Manual Resolution**:
```bash
git checkout develop
git pull origin develop
git merge main
# Resolve conflicts
git add .
git commit -m "merge: Sync develop with main - resolve conflicts"
git push origin develop
```

2. **Communication**: 
- Notify team in Slack/Teams
- Document resolution in PR comments
- Update staging environment after resolution

## Emergency Hotfixes

For critical production issues:

### Option 1: Through PR (Recommended)
```bash
git checkout main
git pull origin main
git checkout -b hotfix/critical-issue
# Make fixes
git push origin hotfix/critical-issue
# Create PR to main for review
```

### Option 2: Direct Push (Admin Emergency Only)
```bash
git checkout main
git pull origin main
# Make critical fix
git add .
git commit -m "hotfix: Emergency fix for production issue"
git push origin main
```

**Important**: In both cases, the sync workflow will automatically merge the hotfix into `develop`, ensuring staging has the fix too.

## Rollback Procedures

### Production Rollback
```bash
# Revert merge commit in main
git checkout main
git revert -m 1 <merge-commit-hash>
git push origin main
```

### Staging Rollback
```bash
# Revert merge commit in develop
git checkout develop
git revert <merge-commit-hash>
git push origin develop
```

## Monitoring and Maintenance

### Weekly Tasks
- Review and clean up old `dev/*` branches
- Verify `develop` is in sync with `main`
- Check for pending dependency updates

### Monthly Tasks
- Review branch protection rules
- Audit user permissions
- Review and update this documentation

## FAQ

**Q: What if I accidentally push to main directly?**
A: Branch protection should prevent this. If it happens, immediately notify the team and create a proper PR for review.

**Q: Can I merge directly from a dev/* branch to main?**
A: No. All changes must go through develop (staging) first for proper testing.

**Q: How long should dev/* branches live?**
A: Ideally less than a week. Long-lived feature branches lead to merge conflicts.

**Q: What if develop and main diverge significantly?**
A: This shouldn't happen with automatic syncing. If it does, schedule a team sync meeting to resolve.

## Related Documentation
- [Terraform Tutorial](../TERRAFORM_TUTORIAL.md)
- [GitHub Secrets Setup](./GITHUB_SECRETS_SETUP.md)
- [GitHub Actions Workflows](../.github/workflows/)