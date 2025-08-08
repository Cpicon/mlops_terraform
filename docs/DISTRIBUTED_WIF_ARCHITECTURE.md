# Distributed Workload Identity Federation (WIF) Architecture

## Overview

This project uses a **Distributed WIF Architecture** where each environment (dev, stage, prod) has its own Workload Identity Federation setup in its own Google Cloud Project. This provides better security isolation and follows the principle of least privilege.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         GitHub Actions                        │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Workflow determines environment based on trigger:    │    │
│  │ • PR to develop → stage                             │    │
│  │ • PR to main → prod                                 │    │
│  │ • Push to dev/* → dev                               │    │
│  └─────────────────────────────────────────────────────┘    │
└───────────────┬──────────────────────────────────────────────┘
                │ Authenticate with environment-specific WIF
                ▼
┌──────────────────────────────────────────────────────────────┐
│                    Google Cloud Projects                      │
│                                                               │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │   Dev Project    │  │  Stage Project   │  │ Prod Project│ │
│  │                  │  │                  │  │             │ │
│  │ WIF Pool:        │  │ WIF Pool:        │  │ WIF Pool:   │ │
│  │ • github-pool    │  │ • github-pool    │  │ • github-pool│
│  │                  │  │                  │  │             │ │
│  │ WIF Provider:    │  │ WIF Provider:    │  │ WIF Provider:│ │
│  │ • github-provider│  │ • github-provider│  │ • github-   │ │
│  │                  │  │                  │  │   provider  │ │
│  │ Service Accounts:│  │ Service Accounts:│  │ Service     │ │
│  │ • terraform-dev  │  │ • terraform-stage│  │ Accounts:   │ │
│  │ • terraform-dev- │  │ • terraform-     │  │ • terraform-│ │
│  │   resources      │  │   stage-resources│  │   prod      │ │
│  └──────────────────┘  └──────────────────┘  │ • terraform-│ │
│                                               │   prod-     │ │
│                                               │   resources │ │
│                                               └────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Environment-Specific WIF Setup

Each environment has its own:
- **Workload Identity Pool**: `github-pool` (same name, different project)
- **Workload Identity Provider**: `github-provider` (same name, different project)
- **Service Accounts**: Environment-specific SAs for state and resource management

### 2. GitHub Secrets Configuration

Required secrets for distributed WIF:
- `GCP_DEV_PROJECT_NUMBER`: Project number for dev environment
- `GCP_STAGE_PROJECT_NUMBER`: Project number for stage environment
- `GCP_PROD_PROJECT_NUMBER`: Project number for prod environment
- `GCP_PROJECT_PREFIX`: Common prefix for all projects (e.g., "mycompany-mlops")

### 3. Workflow Authentication

The GitHub Actions workflow dynamically selects the correct WIF based on the target environment:

```yaml
workload_identity_provider: 'projects/${{ secrets[format('GCP_{0}_PROJECT_NUMBER', env.ENVIRONMENT == 'dev' && 'DEV' || env.ENVIRONMENT == 'stage' && 'STAGE' || 'PROD')] }}/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
```

## Setup Process

### Step 1: Configure WIF for Each Environment

```bash
# Setup WIF in dev project
just setup-wif dev <github-org> <github-repo>

# Setup WIF in stage project
just setup-wif stage <github-org> <github-repo>

# Setup WIF in prod project
just setup-wif prod <github-org> <github-repo>
```

### Step 2: Set GitHub Project Number Secrets

```bash
# This reads project numbers and sets GitHub secrets
just setup-project-secrets
```

### Step 3: Verify WIF Setup

```bash
# Verify each environment
just verify-wif dev
just verify-wif stage
just verify-wif prod
```

### Step 4: Configure Terraform Variables

```bash
# Set Terraform variable secrets for each environment
just github-secrets add --all
```

## Benefits of Distributed WIF

### 1. **Security Isolation**
- Each environment's WIF is isolated in its own project
- No cross-project authentication required
- Compromise of one environment doesn't affect others

### 2. **Simplified Permissions**
- Service accounts only need permissions within their own project
- No complex cross-project IAM bindings
- Easier to audit and manage

### 3. **Environment Independence**
- Each environment can be managed independently
- Different teams can manage different environments
- Easier to implement different security policies per environment

### 4. **Compliance & Governance**
- Clear separation of duties
- Better audit trails per environment
- Meets regulatory requirements for environment isolation

## Comparison with Centralized WIF

| Aspect | Distributed WIF | Centralized WIF |
|--------|----------------|-----------------|
| **Setup Complexity** | Higher (3 WIF setups) | Lower (1 WIF setup) |
| **Security Isolation** | High | Medium |
| **Cross-Project Permissions** | Not required | Required |
| **Management Overhead** | Higher | Lower |
| **Flexibility** | High | Medium |
| **Best For** | Production systems, regulated environments | Development, small teams |

## Troubleshooting

### Issue: WIF authentication fails for a specific environment

1. **Check project number secret exists**:
   ```bash
   gh secret list | grep GCP_.*_PROJECT_NUMBER
   ```

2. **Verify WIF is set up in that environment**:
   ```bash
   just verify-wif <env>
   ```

3. **Check service account permissions**:
   ```bash
   gcloud projects get-iam-policy <project-id> \
     --flatten="bindings[].members" \
     --filter="bindings.members:terraform-<env>"
   ```

### Issue: "Workload identity pool does not exist"

This means WIF hasn't been set up in that environment's project:
```bash
just setup-wif <env> <github-org> <github-repo>
```

### Issue: Different project numbers between environments

This is expected! Each environment has its own project with its own project number. Ensure all three are set:
```bash
just setup-project-secrets
```

## Migration from Centralized to Distributed WIF

If you're migrating from a centralized WIF setup:

1. **Keep existing centralized WIF** (optional, for rollback)

2. **Setup distributed WIF**:
   ```bash
   just setup-wif dev <org> <repo>
   just setup-wif stage <org> <repo>
   just setup-wif prod <org> <repo>
   ```

3. **Update GitHub secrets**:
   ```bash
   # Remove old singular secret (if exists)
   gh secret delete GCP_PROJECT_NUMBER
   
   # Add environment-specific secrets
   just setup-project-secrets
   ```

4. **Update workflows** (already done in this setup)

5. **Test with a small change**:
   ```bash
   git checkout -b dev/test-distributed-wif
   # Make a small change
   git push origin dev/test-distributed-wif
   ```

6. **Clean up centralized WIF** (after successful testing)

## Security Best Practices

1. **Regularly rotate service account keys** (if any are used)
2. **Audit WIF attribute conditions** to ensure they match your repository
3. **Use branch protection** to prevent unauthorized changes
4. **Monitor authentication logs** in Cloud Logging
5. **Implement least privilege** - only grant necessary permissions
6. **Regular security reviews** of WIF configurations

## Related Documentation

- [Workload Identity Federation Setup](../scripts/setup-wif.sh)
- [GitHub Branch Protection Setup](./GITHUB_BRANCH_PROTECTION_SETUP.md)
- [GitHub Secrets Setup](./GITHUB_SECRETS_SETUP.md)
- [Google Documentation: Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)