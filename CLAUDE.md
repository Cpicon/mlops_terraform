# Claude Assistant Rules for This Repository

## CRITICAL GIT RULES - NEVER VIOLATE THESE

### ❌ FORBIDDEN COMMANDS
1. **NEVER use `git add -A`** - This adds ALL files including untracked local work
2. **NEVER use `git add .`** - This can add unintended files
3. **NEVER use `git rm`** - This deletes files from the filesystem

### ✅ ALWAYS USE INSTEAD
1. **Use specific file paths**: `git add path/to/specific/file.ext`
2. **To remove from git but keep locally**: `git rm --cached path/to/file`
3. **Always verify before adding**: Run `git status` first to see what will be added
4. **Add files individually**: Better to be explicit than accidentally commit wrong files

## Project Context

This is an MLOps Terraform project with:
- Multiple environments (dev, stage, prod)
- GitHub Actions CI/CD pipeline
- Workload Identity Federation setup
- Branch protection with automated sync

## Local Work Files (DO NOT COMMIT)
- `TERRAFORM_TUTORIAL.md` - Local documentation work
- `modules/gcs-bucket/` - Local module development
- `environments/*/BIGQUERY_ACCESS_EXPLAINED.md` - Local documentation

## Important Commands to Run After Changes
- Lint check: `npm run lint` (if applicable)
- Type check: `npm run typecheck` (if applicable)
- Terraform format: `terraform fmt -recursive`
- Terraform validate: `terraform validate`

## Repository-Specific Notes
- The sync-develop workflow uses `SYNC_TOKEN` for branch protection bypass
- GitHub converts all secret names to UPPERCASE
- The github-actions[bot] cannot be added to bypass lists (GitHub limitation)

## Development Workflow
1. Create feature branches from `develop`: `git checkout -b dev/feature-name`
2. Make changes and test locally
3. Commit with specific file paths only
4. Push and create PR to `develop` for staging
5. After testing, PR from `develop` to `main` for production

Remember: When in doubt, ask the user before adding files to git!