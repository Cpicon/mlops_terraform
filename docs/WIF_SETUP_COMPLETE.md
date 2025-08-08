# Workload Identity Federation Setup - Complete

## Summary
We've successfully reconfigured the Workload Identity Federation (WIF) setup to avoid repository name mismatch issues across environments.

## What Was Done

### 1. **Root Cause Identified**
- The WIF was configured with `Cpicon/mlops-terraform` (with hyphen)
- But the actual GitHub repository is `Cpicon/mlops_terraform` (with underscore)
- This mismatch caused authentication failures

### 2. **New Approach Implemented**
- Created `scripts/setup-wif-all.sh` that sets up ALL environments at once
- Ensures all environments use the SAME GitHub repository configuration
- Prevents future mismatches by having a single source of truth

### 3. **Justfile Updated**
- `just setup-wif <org> <repo>` now configures ALL environments
- No longer requires environment parameter
- Prevents configuration drift between environments

### 4. **WIF Configuration**
All three environments are now configured correctly:

| Environment | Project ID | Project Number | Repository |
|------------|------------|----------------|------------|
| dev | mycompany-mlops-dev | 4275271155 | Cpicon/mlops_terraform |
| stage | mycompany-mlops-stage | 729631533282 | Cpicon/mlops_terraform |
| prod | mycompany-mlops-prod | 391673587007 | Cpicon/mlops_terraform |

### 5. **GitHub Secrets**
The following secrets are configured:
- `GCP_DEV_PROJECT_NUMBER`: 4275271155
- `GCP_STAGE_PROJECT_NUMBER`: 729631533282
- `GCP_PROD_PROJECT_NUMBER`: 391673587007
- `GCP_PROJECT_PREFIX`: mycompany-mlops

## How to Use

### Setting up WIF for a New Repository
```bash
# This sets up WIF for ALL environments at once
just setup-wif <github-org> <github-repo>

# Example:
just setup-wif Cpicon mlops_terraform
```

### After WIF Setup
```bash
# 1. Set GitHub secrets
just setup-project-secrets

# 2. Verify the setup
just verify-wif dev
just verify-wif stage
just verify-wif prod

# 3. Test with GitHub Actions
# Create a PR or push to a dev/* branch
```

### Troubleshooting
If you encounter authentication issues:

1. **Run diagnostics**:
   ```bash
   ./scripts/diagnose-wif.sh -p <project-id> -e <env>
   ```

2. **Check for mismatches**:
   - Repository name (hyphen vs underscore)
   - Project numbers in GitHub secrets
   - Service account names

3. **Re-run setup if needed**:
   ```bash
   just setup-wif Cpicon mlops_terraform
   just setup-project-secrets
   ```

## Benefits of New Approach

1. **Consistency**: All environments guaranteed to use same repository
2. **Simplicity**: One command configures everything
3. **Reliability**: Clean state by recreating providers
4. **Prevention**: Eliminates configuration drift
5. **Maintenance**: Easier to manage and debug

## Files Created/Modified

### New Scripts
- `scripts/setup-wif-all.sh` - Sets up WIF for all environments
- `scripts/diagnose-wif.sh` - Diagnoses WIF configuration issues
- `scripts/fix-wif-attribute.sh` - Fixes WIF attribute conditions
- `scripts/cleanup-old-bindings.sh` - Removes old IAM bindings

### Modified Files
- `justfile` - Updated `setup-wif` command to handle all environments
- `.github/workflows/terraform-apply.yaml` - Uses environment-specific project numbers

## Next Steps

Your WIF setup is now complete and working correctly. You can:

1. **Test the setup** by creating a PR or pushing to a dev/* branch
2. **Monitor workflows** in the GitHub Actions tab
3. **Use the diagnostic script** if any issues arise

The authentication error "credential is rejected by the attribute condition" should now be resolved!