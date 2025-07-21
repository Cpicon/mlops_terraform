# MLOps Terraform Infrastructure Management
# ========================================
# This Justfile provides convenient commands for setting up and managing
# MLOps infrastructure across Dev/Stage/Production environments.
#
# Usage: just <command> [environment]
# Example: just setup-backend dev
#          just setup-all

# Set shell to bash for better compatibility
set shell := ["bash", "-c"]

# Default recipe - show available commands
default:
    @just --list

# Apply Terraform for specific environment
apply ENV:
    #!/bin/bash
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Validate environment
    just _check_env {{ENV}}
    
    # Check if terraform.tfvars exists for this environment
    if [ ! -f "environments/{{ENV}}/terraform.tfvars" ]; then
        echo "❌ terraform.tfvars not found in environments/{{ENV}}/"
        echo "Please create it by running: just create-tfvars {{ENV}}"
        exit 1
    fi
    
    # Check if terraform is initialized
    if [ ! -d "environments/{{ENV}}/.terraform" ]; then
        echo "❌ Terraform not initialized for {{ENV}}"
        echo "Please run: just init {{ENV}}"
        exit 1
    fi
    
    echo "🚀 Applying Terraform for {{ENV}} environment..."
    echo "  Working directory: environments/{{ENV}}"
    cd environments/{{ENV}}
    
    # Production requires confirmation
    if [[ "{{ENV}}" == "prod" || "{{ENV}}" == "production" ]]; then
        echo "⚠️  You are about to apply changes to PRODUCTION!"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "❌ Operation cancelled"
            exit 1
        fi
        terraform apply
    else
        terraform apply -auto-approve
    fi

# Clean up generated files
clean:
    @echo "🧹 Cleaning up generated files..."
    rm -f terraform-backend-config.tf
    rm -f .env-mlops
    rm -f environments/*/terraform.tfvars
    rm -f environments/*/backend.tf
    rm -f environments/*/backend.conf  # Clean up old .conf files
    rm -f environments/*/.terraform.lock.hcl
    rm -rf environments/*/.terraform/
    rm -f .terraform.lock.hcl
    rm -rf .terraform/
    @echo "✅ Cleanup complete"

# Create GCP projects for specific environment or all environments
create-projects ENV:
    #!/bin/bash
    # Handle --all flag
    if [[ "{{ENV}}" == "--all" || "{{ENV}}" == "all" ]]; then
        echo "🏗️ Creating projects for all environments..."
        
        # Track results for each environment
        FAILED_ENVS=()
        
        echo "📋 Processing development environment..."
        if ! just _create_project_single dev; then
            FAILED_ENVS+=("dev")
            echo "❌ Development environment setup failed"
        fi
        echo
        
        echo "📋 Processing staging environment..."
        if ! just _create_project_single stage; then
            FAILED_ENVS+=("stage")
            echo "❌ Staging environment setup failed"
        fi
        echo
        
        echo "📋 Processing production environment..."
        if ! just _create_project_single prod; then
            FAILED_ENVS+=("prod")
            echo "❌ Production environment setup failed"
        fi
        echo
        
        # Summary
        if [[ ${#FAILED_ENVS[@]} -eq 0 ]]; then
            echo "✅ All projects created/configured successfully!"
            exit 0
        else
            echo "⚠️  Project setup completed with some failures:"
            for env in "${FAILED_ENVS[@]}"; do
                echo "  ❌ $env environment failed"
            done
            echo
            echo "💡 You can:"
            echo "  - Fix the issues and re-run: just create-projects --all"
            echo "  - Or setup individual environments: just create-projects <env>"
            exit 1
        fi
    fi
    
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Validate and create project for single environment
    just _check_env {{ENV}}
    just _create_project_single {{ENV}}

# Create provider configuration for specific environment
create-provider-config ENV:
    #!/bin/bash
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Validate environment
    just _check_env {{ENV}}
    
    # Get environment-specific values
    ENV="{{ENV}}"
    PROJECT=$(just _get_project {{ENV}})
    REGION=$(just _get_region {{ENV}})
    ZONE="${REGION}-a"
    
    # Ensure environment structure exists
    just _create_env_structure {{ENV}}
    
    echo "🔧 Creating provider configuration for {{ENV}} environment..."
    
        # Create provider.tf file
    {
        echo "terraform {"
        echo "  required_providers {"
        echo "    google = {"
        echo "      source  = \"hashicorp/google\""
        echo "      version = \">= 6.0\""
        echo "    }"
        echo "  }"
        echo "  required_version = \">= 1.0\""
        echo "}"
        echo ''
        echo "provider \"google\" {"
        echo "  project = var.project_id"
        echo "  region  = var.region"
        echo "  zone    = var.zone"
        echo ''
        echo "  # Use Application Default Credentials (user must be logged in with gcloud)"
        echo "  # The user's credentials will be used to impersonate the executor service account"
        echo "  "
        echo "  # Impersonate the executor service account for all resource operations"
        echo "  impersonate_service_account = \"terraform-${ENV}-resources@${PROJECT}.iam.gserviceaccount.com\""
        echo "}"
    } > "environments/{{ENV}}/provider.tf"
    
    echo "  ✅ Created provider.tf with impersonation for terraform-${ENV}-resources@${PROJECT}.iam.gserviceaccount.com"
    echo "  📝 Note: Users must have permission to impersonate this service account"

# Create service accounts for specific environment  
create-service-accounts ENV:
    #!/bin/bash
    # Load environment variables first (needed for both individual and --all)
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Handle --all flag (after env vars are loaded)
    if [[ "{{ENV}}" == "--all" || "{{ENV}}" == "all" ]]; then
        echo "🤖 Creating service accounts for all environments..."
        just _create_sa_single dev
        echo
        just _create_sa_single stage
        echo  
        just _create_sa_single prod
        echo "✅ Service accounts created for all environments!"
        exit 0
    fi
    
    # Validate and create service account for single environment
    just _check_env {{ENV}}
    just _create_sa_single {{ENV}}

# Create environment-specific tfvars file
create-tfvars ENV:
    #!/bin/bash
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Validate environment
    just _check_env {{ENV}}
    
    # Get environment-specific values
    PROJECT=$(just _get_project {{ENV}})
    REGION=$(just _get_region {{ENV}})
    SA=$(just _get_sa {{ENV}})
    
    # Ensure environment structure exists
    just _create_env_structure {{ENV}}
    
    # Check if tfvars already exists
    if [ -f "environments/{{ENV}}/terraform.tfvars" ]; then
        echo "⚠️  terraform.tfvars already exists for {{ENV}}"
        read -p "Overwrite? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "ℹ️  Keeping existing terraform.tfvars"
            exit 0
        fi
    fi
    
    # Generate tfvars file
    echo "# {{ENV}} Environment Configuration" > environments/{{ENV}}/terraform.tfvars
    echo "# Generated on $(date)" >> environments/{{ENV}}/terraform.tfvars
    echo "" >> environments/{{ENV}}/terraform.tfvars
    echo "project_id     = \"$PROJECT\"" >> environments/{{ENV}}/terraform.tfvars
    echo "project_number = \"$(gcloud projects describe $PROJECT --format='value(projectNumber)' 2>/dev/null || echo 'UPDATE_ME')\"" >> environments/{{ENV}}/terraform.tfvars
    echo "region         = \"$REGION\"" >> environments/{{ENV}}/terraform.tfvars
    echo "zone           = \"${REGION}-a\"" >> environments/{{ENV}}/terraform.tfvars
    echo "" >> environments/{{ENV}}/terraform.tfvars
    echo "# Add environment-specific variables below" >> environments/{{ENV}}/terraform.tfvars
    echo "# environment = \"{{ENV}}\"" >> environments/{{ENV}}/terraform.tfvars
    
    echo "✅ Created environments/{{ENV}}/terraform.tfvars"
    echo "💡 Remember to:"
    echo "   1. Update project_number if needed"
    echo "   2. Add any environment-specific variables"
    echo "   3. Ensure you have permission to impersonate the service accounts"

# Destroy Terraform for specific environment
destroy ENV:
    #!/bin/bash
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Validate environment
    just _check_env {{ENV}}
    
    # Check if terraform.tfvars exists for this environment
    if [ ! -f "environments/{{ENV}}/terraform.tfvars" ]; then
        echo "❌ terraform.tfvars not found in environments/{{ENV}}/"
        echo "No infrastructure to destroy for {{ENV}} environment"
        exit 1
    fi
    
    # Check if terraform is initialized
    if [ ! -d "environments/{{ENV}}/.terraform" ]; then
        echo "❌ Terraform not initialized for {{ENV}}"
        echo "Please run: just init {{ENV}}"
        exit 1
    fi
    
    echo "💥 DESTROYING {{ENV}} environment infrastructure..."
    echo "⚠️  This action cannot be undone!"
    read -p "Type 'DELETE' to confirm: " confirm
    if [[ "$confirm" != "DELETE" ]]; then
        echo "❌ Operation cancelled"
        exit 1
    fi
    
    cd environments/{{ENV}}
    terraform destroy

# Download service account keys for specific environment
download-sa-keys ENV:
    #!/bin/bash
    # Handle --all flag
    if [[ "{{ENV}}" == "--all" || "{{ENV}}" == "all" ]]; then
        echo "🔑 Downloading service account keys for all environments..."
        just _download_sa_key_single dev
        echo
        just _download_sa_key_single stage
        echo
        just _download_sa_key_single prod
        echo "✅ Service account keys downloaded for all environments!"
        exit 0
    fi
    
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Validate and download key for single environment
    just _check_env {{ENV}}
    just _download_sa_key_single {{ENV}}

# Enable required APIs for specific environment
enable-apis ENV:
    #!/bin/bash
    # Handle --all flag
    if [[ "{{ENV}}" == "--all" || "{{ENV}}" == "all" ]]; then
        echo "🔧 Enabling APIs for all environments..."
        just _enable_apis_single dev
        echo
        just _enable_apis_single stage  
        echo
        just _enable_apis_single prod
        echo "✅ APIs enabled for all environments!"
        exit 0
    fi
    
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Validate and enable APIs for single environment
    just _check_env {{ENV}}
    just _enable_apis_single {{ENV}}

# Grant impersonation permissions to users/groups for service accounts
grant-impersonation ENV MEMBER:
    #!/bin/bash
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Validate environment
    just _check_env {{ENV}}
    
    # Get environment-specific values
    PROJECT=$(just _get_project {{ENV}})
    SA=$(just _get_sa {{ENV}})
    RESOURCES_SA="terraform-{{ENV}}-resources@${PROJECT}.iam.gserviceaccount.com"
    
    echo "🔐 Granting impersonation permissions for {{ENV}} environment..."
    echo "  Project: $PROJECT"
    echo "  Member: {{MEMBER}}"
    echo ""
    
    # Validate member format
    if [[ ! "{{MEMBER}}" =~ ^(user:|group:|serviceAccount:) ]]; then
        echo "❌ Invalid member format. Must start with 'user:', 'group:', or 'serviceAccount:'"
        echo "Examples:"
        echo "  user:john@example.com"
        echo "  group:terraform-admins@example.com"
        echo "  serviceAccount:ci-cd@project.iam.gserviceaccount.com"
        exit 1
    fi
    
    # Set the project context
    gcloud config set project "$PROJECT"
    
    # Grant permission to impersonate the state management SA
    echo "  🔑 Granting permission to impersonate state management SA..."
    if gcloud iam service-accounts add-iam-policy-binding "$SA" \
        --member="{{MEMBER}}" \
        --role="roles/iam.serviceAccountTokenCreator" \
        --quiet; then
        echo "  ✅ Granted impersonation rights for: $SA"
    else
        echo "  ❌ Failed to grant impersonation rights for state management SA"
        exit 1
    fi
    
    # Grant permission to impersonate the executor SA
    echo "  🔑 Granting permission to impersonate executor SA..."
    if gcloud iam service-accounts add-iam-policy-binding "$RESOURCES_SA" \
        --member="{{MEMBER}}" \
        --role="roles/iam.serviceAccountTokenCreator" \
        --quiet; then
        echo "  ✅ Granted impersonation rights for: $RESOURCES_SA"
    else
        echo "  ❌ Failed to grant impersonation rights for executor SA"
        exit 1
    fi
    
    echo ""
    echo "✅ Successfully granted impersonation permissions to {{MEMBER}}"
    echo ""
    echo "📝 {{MEMBER}} can now:"
    echo "   - Impersonate $SA (for state management)"
    echo "   - Impersonate $RESOURCES_SA (for infrastructure provisioning)"
    echo ""
    echo "🚀 To use these permissions, {{MEMBER}} should:"
    echo "   1. Authenticate with: gcloud auth login"
    echo "   2. Set project: gcloud config set project $PROJECT"
    echo "   3. Run Terraform commands normally (backend.tf and provider.tf will handle impersonation)"

# Show help for specific commands
help COMMAND="":
    #!/bin/bash
    case "{{COMMAND}}" in
        "setup-vars")
            echo "Setup environment variables interactively"
            echo "This command will prompt for project IDs, regions, and generate service account names"
            ;;
        "setup-backend")
            echo "Setup GCS backend for specified environment or all environments"
            echo "Usage: just setup-backend <env|--all>"
            echo "Examples:"
            echo "  just setup-backend dev     # Setup backend for development"
            echo "  just setup-backend --all   # Setup backends for all environments"
            ;;
        "create-projects")
            echo "Create GCP projects for environment(s) with billing enabled"
            echo "Usage: just create-projects <env|--all>"
            echo "Examples:"
            echo "  just create-projects dev     # Create project for development"
            echo "  just create-projects --all   # Create projects for all environments"
            echo "Note: This command will also set up billing as projects are useless without it"
            ;;
        "enable-apis")
            echo "Enable required Google Cloud APIs for environment(s)"
            echo "Usage: just enable-apis <env|--all>"
            echo "Examples:"
            echo "  just enable-apis dev      # Enable APIs for development"
            echo "  just enable-apis --all    # Enable APIs for all environments"
            echo "Note: Projects must exist before enabling APIs"
            ;;
        "create-service-accounts")
            echo "Create Terraform service accounts for environment(s)"
            echo "Usage: just create-service-accounts <env|--all>"
            echo "Examples:"
            echo "  just create-service-accounts stage  # Create SA for staging"
            echo "  just create-service-accounts --all  # Create SAs for all environments"
            ;;
        "download-sa-keys")
            echo "Download service account keys for environment(s)"
            echo "Usage: just download-sa-keys <env|--all>"
            echo "Examples:"
            echo "  just download-sa-keys prod    # Download key for production"
            echo "  just download-sa-keys --all   # Download keys for all environments"
            echo "Note: This is deprecated in favor of impersonation-based authentication"
            ;;
        "grant-impersonation")
            echo "Grant impersonation permissions to users/groups for service accounts"
            echo "Usage: just grant-impersonation <env> <member>"
            echo "Examples:"
            echo "  just grant-impersonation dev user:john@example.com"
            echo "  just grant-impersonation stage group:terraform-admins@example.com"
            echo "  just grant-impersonation prod serviceAccount:ci-cd@project.iam.gserviceaccount.com"
            echo "This grants permission to impersonate both:"
            echo "  - terraform-<env>@ (state management)"
            echo "  - terraform-<env>-resources@ (infrastructure provisioning)"
            ;;
        "setup")
            echo "Setup environments - specific environment or all environments"
            echo "Usage: just setup [env]"
            echo "Examples:"
            echo "  just setup         # Setup all environments (default)"
            echo "  just setup all     # Setup all environments"
            echo "  just setup --all   # Setup all environments"
            echo "  just setup dev     # Setup only development environment"
            echo "This includes environment variables, backends, tfvars, and terraform init"
            ;;
        *)
            echo "📚 MLOps Terraform Infrastructure Management"
            echo "==========================================="
            echo
            echo "🚀 Quick Start:"
            echo "  just setup-vars                # Configure environment variables"
            echo "  just create-projects --all     # Create GCP projects with billing (if needed)"
            echo "  just enable-apis --all         # Enable required APIs"
            echo "  just create-service-accounts --all  # Create service accounts"
            echo "  just setup                      # Setup all environments"
            echo "  just grant-impersonation dev user:you@example.com  # Grant yourself access"
            echo "  just status                     # Check status of all environments"
            echo
            echo "🔧 Environment Management:"
            echo "  just setup <env>                # Setup specific environment (or 'all')"
            echo "  just create-projects <env|--all>          # Create GCP projects with billing"
            echo "  just enable-apis <env|--all>    # Enable APIs"
            echo "  just create-service-accounts <env|--all>  # Create service accounts"
            echo "  just download-sa-keys <env|--all>         # Download SA keys"
            echo "  just init <env>                 # Initialize Terraform in environment directory"
            echo "  just plan <env>                 # Plan changes with env-specific vars"
            echo "  just apply <env>                # Apply changes with env-specific vars"
            echo
            echo "💡 Infrastructure Approach:"
            echo "  • Each environment has its own Terraform configuration in environments/<env>/"
            echo "  • Environment-specific: main.tf, variables.tf, outputs.tf, terraform.tfvars, backend.tf, provider.tf"
            echo "  • Dedicated GCS bucket per environment for state isolation"
            echo "  • Two service accounts per environment:"
            echo "    - terraform-<env>: For state management"
            echo "    - terraform-<env>-resources: For resource provisioning (impersonated)"
            echo "  • Complete environment isolation and independent deployments"
            echo
            echo "📋 Available environments: dev, stage, prod"
            echo "📖 For more details: just help <command>"
            ;;
    esac 

# Initialize Terraform for specific environment
init ENV:
    #!/bin/bash
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Validate environment
    just _check_env {{ENV}}
    
    # Get environment-specific values
    PROJECT=$(just _get_project {{ENV}})
    
    # Ensure environment structure exists
    just _create_env_structure {{ENV}}
    
    echo "🔧 Initializing Terraform for {{ENV}} environment..."
    echo "  Working directory: environments/{{ENV}}"
    echo "  Backend: ${PROJECT}-terraform-state bucket"
    
    # Create backend configuration if it doesn't exist
    if [ ! -f "environments/{{ENV}}/backend.tf" ]; then
        just _create_backend_config {{ENV}}
    else
        echo "  ℹ️  Backend configuration already exists"
    fi
    
    # Change to environment directory and initialize
    cd environments/{{ENV}}
    terraform init

# Load environment variables from .env-mlops if it exists
load-env-vars:
    #!/bin/bash
    if [ -f .env-mlops ]; then
        echo "💾 Loading environment variables from .env-mlops..."
        source .env-mlops
        echo "✅ Environment variables loaded"
        echo "Development: $DEV_PROJECT ($DEV_REGION)"
        echo "Staging: $STAGE_PROJECT ($STAGE_REGION)"
        echo "Production: $PROD_PROJECT ($PROD_REGION)"
    else
        echo "❌ No .env-mlops file found. Run: just setup-vars"
        exit 1
    fi

# Plan Terraform for specific environment
plan ENV:
    #!/bin/bash
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Validate environment
    just _check_env {{ENV}}
    
    # Check if terraform.tfvars exists for this environment
    if [ ! -f "environments/{{ENV}}/terraform.tfvars" ]; then
        echo "❌ terraform.tfvars not found in environments/{{ENV}}/"
        echo "Please create it by running: just create-tfvars {{ENV}}"
        exit 1
    fi
    
    # Check if terraform is initialized
    if [ ! -d "environments/{{ENV}}/.terraform" ]; then
        echo "❌ Terraform not initialized for {{ENV}}"
        echo "Please run: just init {{ENV}}"
        exit 1
    fi
    
    echo "📋 Planning Terraform for {{ENV}} environment..."
    echo "  Working directory: environments/{{ENV}}"
    cd environments/{{ENV}}
    terraform plan

# Setup backend for specific environment or all environments
setup-backend ENV:
    #!/bin/bash
    # Load environment variables first (needed for both individual and --all)
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Handle --all flag (after env vars are loaded)
    if [[ "{{ENV}}" == "--all" || "{{ENV}}" == "all" ]]; then
        echo "🚀 Setting up backends for all environments..."
        echo
        just setup-backend dev
        echo
        just setup-backend stage
        echo
        just setup-backend prod
        echo "✅ All backends configured!"
        exit 0
    fi
    
    # Validate specific environment
    just _check_env {{ENV}}
    
    # Get environment-specific values
    PROJECT=$(just _get_project {{ENV}})
    REGION=$(just _get_region {{ENV}})
    SA=$(just _get_sa {{ENV}})
    
    echo "🔧 Setting up backend for {{ENV}} environment"
    echo "  Project: $PROJECT"
    echo "  Region:  $REGION"
    echo "  SA:      $SA"
    echo "  Bucket:  ${PROJECT}-terraform-state"
    echo
    
    # Each environment gets its own bucket in its own project
    echo "📦 Creating dedicated bucket for {{ENV}} environment..."
    ./setup-terraform-backend.sh --admin-setup \
        --project "$PROJECT" \
        --service-account "$SA" \
        --key-file "${PROJECT}-terraform-key.json" \
        --bucket-prefix "${PROJECT}-terraform-state" \
        --location "$REGION"

# Setup environments - single environment or all environments  
setup ENV="all":
    #!/bin/bash
    # Handle help flags
    if [[ "{{ENV}}" == "--help" || "{{ENV}}" == "-h" ]]; then
        just help setup
        exit 0
    fi
    
    if [[ "{{ENV}}" == "all" || "{{ENV}}" == "--all" ]]; then
        echo "🚀 Complete setup for all environments..."
        
        # Ensure environment variables are configured
        if [ ! -f .env-mlops ]; then
            just setup-vars
        fi
        
        echo "Setting up development environment..."
        if ! just _setup_single_env dev; then
            echo "❌ Failed to setup development environment"
            exit 1
        fi
        echo
        
        echo "Setting up staging environment..."  
        if ! just _setup_single_env stage; then
            echo "❌ Failed to setup staging environment"
            exit 1
        fi
        echo
        
        echo "Setting up production environment..."
        if ! just _setup_single_env prod; then
            echo "❌ Failed to setup production environment"
            exit 1
        fi
        echo
        
        echo "🎉 All environments are ready!"
    else
        echo "🎯 Complete setup for {{ENV}} environment..."
        if ! just _setup_single_env {{ENV}}; then
            echo "❌ Failed to setup {{ENV}} environment"
            exit 1
        fi
        echo "✅ {{ENV}} environment ready for use!"
    fi

# Setup environment variables interactively
setup-vars:
    @echo "🚀 Setting up environment variables..."
    @if [ -f .env-mlops ]; then \
        echo "📋 Found existing .env-mlops file"; \
        echo "Choose an option:"; \
        echo "1) Load existing variables"; \
        echo "2) Reconfigure variables"; \
        read -p "Enter choice [1]: " choice; \
        if [[ "$choice" == "2" ]]; then \
            source ./setup-environment-variables.sh; \
        else \
            echo "💾 Loading existing variables..."; \
            source .env-mlops; \
            echo "✅ Variables loaded from .env-mlops"; \
        fi \
    else \
        source ./setup-environment-variables.sh; \
    fi

# Show current environment configuration
show-config:
    #!/bin/bash
    if [ ! -f .env-mlops ]; then
        echo "❌ No environment configuration found. Run: just setup-vars"
        exit 1
    fi
    
    source .env-mlops
    echo "📋 Current Environment Configuration"
    echo "===================================="
    echo
    echo "🔧 Development Environment:"
    echo "  Project: ${DEV_PROJECT:-'NOT SET'}"
    echo "  Region:  ${DEV_REGION:-'NOT SET'}"
    echo "  SA:      ${DEV_SA:-'NOT SET'}"
    echo
    echo "🧪 Staging Environment:"
    echo "  Project: ${STAGE_PROJECT:-'NOT SET'}"
    echo "  Region:  ${STAGE_REGION:-'NOT SET'}"
    echo "  SA:      ${STAGE_SA:-'NOT SET'}"
    echo
    echo "🚀 Production Environment:"
    echo "  Project: ${PROD_PROJECT:-'NOT SET'}"
    echo "  Region:  ${PROD_REGION:-'NOT SET'}"
    echo "  SA:      ${PROD_SA:-'NOT SET'}"

# Show status of all environments
status:
    #!/bin/bash
    echo "📊 MLOps Infrastructure Status"
    echo "=============================="
    
    if [ ! -f .env-mlops ]; then
        echo "❌ Environment variables not configured"
        echo "Run: just setup-vars"
        exit 1
    fi
    
    source .env-mlops
    
    for env in dev stage prod; do
        case $env in
            dev) PROJECT=$DEV_PROJECT; REGION=$DEV_REGION ;;
            stage) PROJECT=$STAGE_PROJECT; REGION=$STAGE_REGION ;;
            prod) PROJECT=$PROD_PROJECT; REGION=$PROD_REGION ;;
        esac
        
        echo
        echo "🔧 $env Environment:"
        echo "  Project: $PROJECT"
        echo "  Region:  $REGION"
        
        # Check if environment directory exists
        if [ -d "environments/$env" ]; then
            echo "  Status:  📁 Environment directory exists"
            
            # Check terraform initialization
            if [ -d "environments/$env/.terraform" ]; then
                echo "           ✅ Terraform initialized"
            else
                echo "           ❌ Terraform not initialized"
            fi
            
            # Check required files
            for file in main.tf variables.tf outputs.tf terraform.tfvars backend.tf provider.tf; do
                if [ -f "environments/$env/$file" ]; then
                    echo "           ✅ $file exists"
                else
                    echo "           ❌ $file missing"
                fi
            done
        else
            echo "  Status:  ❌ Environment directory missing"
        fi
        
        # Check billing status
        BILLING_ENABLED=$(gcloud billing projects describe "$PROJECT" --format="value(billingEnabled)" 2>/dev/null)
        if [[ "$BILLING_ENABLED" == "True" ]]; then
            echo "           ✅ Billing enabled"
        else
            echo "           ❌ Billing NOT enabled"
        fi
        
        # Check if environment's backend bucket exists
        if gsutil ls "gs://${PROJECT}-terraform-state-*" &>/dev/null; then
            echo "           ✅ Backend bucket exists"
        else
            echo "           ❌ Backend bucket missing"
        fi
    done

# ================================================================================
# HELPER FUNCTIONS (Internal use - alphabetical order)
# ================================================================================

# Environment validation function
_check_env ENV:
    #!/bin/bash
    case "{{ENV}}" in
        dev|development)
            if [[ -z "$DEV_PROJECT" || -z "$DEV_REGION" || -z "$DEV_SA" ]]; then
                echo "❌ Development environment variables not set!"
                echo "Run: just setup-vars"
                exit 1
            fi
            ;;
        stage|staging)
            if [[ -z "$STAGE_PROJECT" || -z "$STAGE_REGION" || -z "$STAGE_SA" ]]; then
                echo "❌ Staging environment variables not set!"
                echo "Run: just setup-vars"
                exit 1
            fi
            ;;
        prod|production)
            if [[ -z "$PROD_PROJECT" || -z "$PROD_REGION" || -z "$PROD_SA" ]]; then
                echo "❌ Production environment variables not set!"
                echo "Run: just setup-vars"
                exit 1
            fi
            ;;
        all)
            if [[ -z "$DEV_PROJECT" || -z "$DEV_REGION" || -z "$DEV_SA" || -z "$STAGE_PROJECT" || -z "$STAGE_REGION" || -z "$STAGE_SA" || -z "$PROD_PROJECT" || -z "$PROD_REGION" || -z "$PROD_SA" ]]; then
                echo "❌ All environment variables not set!"
                echo "Run: just setup-vars"
                exit 1
            fi
            ;;
        *)
            echo "❌ Invalid environment: {{ENV}}"
            echo "Valid options: dev, stage, prod"
            exit 1
            ;;
    esac
    echo "✅ {{ENV}} environment variables validated"

# Create backend configuration for specific environment
_create_backend_config ENV:
    #!/bin/bash
    # Load environment variables
    if [ -f .env-mlops ]; then
        source .env-mlops
    else
        echo "❌ Environment variables not configured. Run: just setup-vars"
        exit 1
    fi
    
    # Get environment-specific values
    PROJECT=$(just _get_project {{ENV}})
    SA=$(just _get_sa {{ENV}})
    
    echo "🔧 Creating backend configuration for {{ENV}} environment..."
    
    # Create backend config for this environment using its own bucket
    BUCKET_NAME="${PROJECT}-terraform-state"
    echo "terraform {" > "environments/{{ENV}}/backend.tf"
    echo "  backend \"gcs\" {" >> "environments/{{ENV}}/backend.tf"
    echo "    bucket                      = \"$BUCKET_NAME\"" >> "environments/{{ENV}}/backend.tf"
    echo "    prefix                      = \"terraform/state\"" >> "environments/{{ENV}}/backend.tf"
    echo "    # Use Application Default Credentials (user must be logged in)" >> "environments/{{ENV}}/backend.tf"
    echo "    # User will impersonate the state management service account" >> "environments/{{ENV}}/backend.tf"
    echo "    impersonate_service_account = \"$SA\"" >> "environments/{{ENV}}/backend.tf"
    echo "  }" >> "environments/{{ENV}}/backend.tf"
    echo "}" >> "environments/{{ENV}}/backend.tf"
    echo "  ✅ Created backend.tf with impersonation for $SA"

# Create complete environment directory structure
_create_env_structure ENV:
    #!/bin/bash
    echo "📁 Creating directory structure for {{ENV}} environment..."
    
    # Create environment directory
    mkdir -p environments/{{ENV}}
    
    # Create empty .tf files if they don't exist
    for file in main.tf variables.tf outputs.tf; do
        if [ ! -f "environments/{{ENV}}/$file" ]; then
            touch "environments/{{ENV}}/$file"
            echo "  ✅ Created $file"
        else
            echo "  ℹ️  $file already exists"
        fi
    done

# Internal recipe for creating a single project
_create_project_single ENV:
    #!/bin/bash
    source .env-mlops
    
    PROJECT=$(just _get_project {{ENV}})
    
    echo "🏗️ Creating GCP project for {{ENV}} environment..."
    echo "  Project ID: $PROJECT"
    
    # Check if project already exists and get its state
    if gcloud projects describe "$PROJECT" --quiet 2>/dev/null; then
        PROJECT_STATE=$(gcloud projects describe "$PROJECT" --format="value(lifecycleState)" 2>/dev/null)
        echo "  ℹ️  Project already exists: $PROJECT (State: $PROJECT_STATE)"
        
        # Handle different project states
        if [[ "$PROJECT_STATE" == "DELETE_REQUESTED" ]]; then
            echo "  ⚠️  Project is marked for deletion and cannot be used"
            echo "  💡 Solutions:"
            echo "     - Wait for deletion to complete and create a new project"
            echo "     - Use a different project ID"
            echo "     - Contact support to restore the project (if within 30 days)"
            exit 1
        elif [[ "$PROJECT_STATE" != "ACTIVE" ]]; then
            echo "  ⚠️  Project is not in ACTIVE state: $PROJECT_STATE"
            echo "  💡 Wait for the project to become ACTIVE or use a different project ID"
            exit 1
        fi
        
        # Check billing status for active projects
        BILLING_ENABLED=$(gcloud billing projects describe "$PROJECT" --format="value(billingEnabled)" 2>/dev/null)
        if [[ "$BILLING_ENABLED" == "True" ]]; then
            echo "  ✅ Project ready with billing enabled: $PROJECT"
            exit 0
        else
            echo "  ⚠️  Project exists but billing is not enabled"
            echo "  💳 Setting up billing for existing project..."
            # Call billing setup and handle its exit code properly
            just _setup_billing_for_project "$PROJECT"
            BILLING_RESULT=$?
            if [[ $BILLING_RESULT -eq 0 ]]; then
                echo "  ✅ Project ready with billing enabled: $PROJECT"
                exit 0
            else
                echo "  ❌ Failed to enable billing for existing project"
                exit 1
            fi
        fi
    fi
    
    # Attempt to create the project
    echo "  🔨 Creating project: $PROJECT"
    if gcloud projects create "$PROJECT" --name="MLOps {{ENV}} Environment"; then
        echo "  ✅ Project created successfully: $PROJECT"
        
        # Set the project as the active project for further operations
        gcloud config set project "$PROJECT"
        
        # Enable billing immediately
        echo "  💳 Setting up billing (required for API enablement)..."
        # Call billing setup and handle its exit code properly
        just _setup_billing_for_project "$PROJECT"
        BILLING_RESULT=$?
        if [[ $BILLING_RESULT -eq 0 ]]; then
            echo "  ✅ Project ready with billing enabled: $PROJECT"
            exit 0
        else
            echo "  ❌ Failed to enable billing for new project"
            exit 1
        fi
    else
        echo "  ❌ Failed to create project: $PROJECT"
        echo "  🔍 Possible reasons:"
        echo "     - Project ID already exists globally"
        echo "     - Insufficient permissions"
        echo "     - Billing account not configured"
        echo "     - Organization policies prevent project creation"
        echo "  💡 You may need to:"
        echo "     - Choose a different project ID"
        echo "     - Contact your organization admin"
        echo "     - Set up billing account"
        exit 1
    fi

# Internal recipe for creating service account in a single environment
_create_sa_single ENV:
    #!/bin/bash
    source .env-mlops
    
    PROJECT=$(just _get_project {{ENV}})
    SA=$(just _get_sa {{ENV}})
    
    echo "🤖 Creating service accounts for {{ENV}} environment (Project: $PROJECT)..."
    
    # Set the project context
    gcloud config set project "$PROJECT"
    
    # Get the state bucket name
    BUCKET_NAME="${PROJECT}-terraform-state"
    
    # 1. Create the state management service account (tf-state-manager pattern)
    SA_NAME=$(echo "$SA" | cut -d'@' -f1)
    echo "  👤 Creating state management service account: $SA_NAME"
    
    if gcloud iam service-accounts describe "$SA" --quiet 2>/dev/null; then
        echo "  ℹ️  State management service account already exists: $SA"
    else
        gcloud iam service-accounts create "$SA_NAME" \
            --description="Terraform state management service account for {{ENV}}" \
            --display-name="Terraform {{ENV}} State Manager"
        echo "  ✅ State management service account created: $SA"
    fi
    
    # Grant state management permissions (storage admin only on state bucket)
    echo "  🔑 Granting state bucket permissions to state management SA..."
    # Grant to SA access to the state bucket
    echo "  🔑 Granting access to service account..."
    if gsutil iam ch serviceAccount:${SA}:roles/storage.admin gs://${BUCKET_NAME}; then
        echo "    ✅ Access granted to service account"
    else
        echo "    ❌ Failed to grant access to service account"
        exit 1
    fi
    echo "    ✅ Granted storage.admin role"

    # enabling log audit in SA state management
    echo "  🔑 Enabling log audit in SA state management..."
    gcloud projects add-iam-policy-binding "$PROJECT" \
        --member="serviceAccount:$SA" \
        --role="roles/logging.logWriter" \
        --quiet
    echo "    ✅ Log audit enabled in SA state management"
    
    # 2. Create the executor/resources service account (tf-executor pattern)
    RESOURCES_SA_NAME="terraform-{{ENV}}-resources"
    RESOURCES_SA="${RESOURCES_SA_NAME}@${PROJECT}.iam.gserviceaccount.com"
    echo "  👤 Creating executor service account: $RESOURCES_SA_NAME"
    
    if gcloud iam service-accounts describe "$RESOURCES_SA" --quiet 2>/dev/null; then
        echo "  ℹ️  Executor service account already exists: $RESOURCES_SA"
    else
        gcloud iam service-accounts create "$RESOURCES_SA_NAME" \
            --description="Terraform infrastructure executor service account for {{ENV}}" \
            --display-name="Terraform {{ENV}} Executor"
        echo "  ✅ Executor service account created: $RESOURCES_SA"
    fi
    
    # Grant necessary roles to the executor service account
    echo "  🔑 Granting infrastructure management roles to executor SA..."
    
    # Roles needed for infrastructure provisioning
    EXECUTOR_ROLES=(
        "roles/compute.admin"
        "roles/storage.admin"
        "roles/bigquery.admin"
        "roles/iam.serviceAccountAdmin"
        "roles/resourcemanager.projectIamAdmin"
        "roles/artifactregistry.admin"
        "roles/container.admin"
        "roles/logging.logWriter"
    )
    
    for role in "${EXECUTOR_ROLES[@]}"; do
        echo "    - Granting $role to executor SA..."
        gcloud projects add-iam-policy-binding "$PROJECT" \
            --member="serviceAccount:$RESOURCES_SA" \
            --role="$role" \
            --quiet
    done
    
    echo "  ✅ Service accounts created and configured for {{ENV}} environment"
    echo ""
    echo "  📝 Next steps:"
    echo "     1. Grant users/groups permission to impersonate these service accounts"
    echo "     2. Use 'just grant-impersonation <env> <user/group>' to grant access"

# Internal recipe for downloading service account key for a single environment
_download_sa_key_single ENV:
    #!/bin/bash
    source .env-mlops
    
    PROJECT=$(just _get_project {{ENV}})
    SA=$(just _get_sa {{ENV}})
    KEY_FILE="${PROJECT}-terraform-key.json"
    
    echo "🔑 Downloading service account key for {{ENV}} environment..."
    echo "  Project: $PROJECT"
    echo "  SA:      $SA"
    echo "  Key:     $KEY_FILE"
    
    # Set the project context
    gcloud config set project "$PROJECT"
    
    # Check if key file already exists
    if [ -f "$KEY_FILE" ]; then
        echo "  ⚠️  Key file already exists: $KEY_FILE"
        read -p "  Overwrite existing key? (y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "  ℹ️  Skipping key download for {{ENV}}"
            exit 0
        fi
    fi
    
    # Download the service account key
    gcloud iam service-accounts keys create "$KEY_FILE" \
        --iam-account="$SA"
    
    echo "  ✅ Service account key downloaded: $KEY_FILE"
    echo "  🔒 Keep this file secure and never commit it to version control!"

# Internal recipe for enabling APIs in a single environment
_enable_apis_single ENV:
    #!/bin/bash
    source .env-mlops
    
    PROJECT=$(just _get_project {{ENV}})
    
    echo "🔧 Enabling required APIs for {{ENV}} environment (Project: $PROJECT)..."
    
    # Set the project context
    gcloud config set project "$PROJECT"
    
    # Define required APIs as arrays (compatible with older bash versions)
    apis=(
        "compute.googleapis.com"
        "storage-api.googleapis.com" 
        "iam.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "bigquery.googleapis.com"
        "aiplatform.googleapis.com"
        "container.googleapis.com"
        "cloudbuild.googleapis.com"
    )
    
    api_names=(
        "Compute Engine API"
        "Google Cloud Storage API"
        "Identity and Access Management (IAM) API"
        "Cloud Resource Manager API"
        "BigQuery API"
        "AI Platform API"
        "Kubernetes Engine API"
        "Cloud Build API"
    )
    
    echo "  📡 Enabling APIs one by one..."
    
    # Track failed APIs
    failed_apis=()
    
    # Enable each API individually with progress feedback
    for i in "${!apis[@]}"; do
        api="${apis[$i]}"
        api_name="${api_names[$i]}"
        
        echo "    🔧 Enabling $api_name ($api)..."
        
        # Check if API is already enabled
        if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            echo "    ✅ $api_name is already enabled"
        else
            # Enable the API
            if gcloud services enable "$api" --quiet; then
                echo "    ✅ $api_name enabled successfully"
            else
                echo "    ❌ Failed to enable $api_name"
                failed_apis+=("$api")
            fi
        fi
    done
    
    # Summary
    echo
    if [ ${#failed_apis[@]} -eq 0 ]; then
        echo "✅ All APIs enabled successfully for {{ENV}} environment"
    else
        echo "⚠️  API enablement completed with some failures for {{ENV}} environment:"
        for i in "${!failed_apis[@]}"; do
            failed_api="${failed_apis[$i]}"
            # Find the corresponding name
            for j in "${!apis[@]}"; do
                if [ "${apis[$j]}" = "$failed_api" ]; then
                    echo "    ❌ ${api_names[$j]} ($failed_api)"
                    break
                fi
            done
        done
        echo "💡 You may need to enable billing or check project permissions"
        exit 1
    fi

# Get project ID for environment
_get_project ENV:
    #!/bin/bash
    case "{{ENV}}" in
        dev|development) echo "$DEV_PROJECT" ;;
        stage|staging) echo "$STAGE_PROJECT" ;;
        prod|production) echo "$PROD_PROJECT" ;;
        *) echo ""; exit 1 ;;
    esac

# Get region for environment
_get_region ENV:
    #!/bin/bash
    case "{{ENV}}" in
        dev|development) echo "$DEV_REGION" ;;
        stage|staging) echo "$STAGE_REGION" ;;
        prod|production) echo "$PROD_REGION" ;;
        *) echo ""; exit 1 ;;
    esac

# Get service account for environment
_get_sa ENV:
    #!/bin/bash
    case "{{ENV}}" in
        dev|development) echo "$DEV_SA" ;;
        stage|staging) echo "$STAGE_SA" ;;
        prod|production) echo "$PROD_SA" ;;
        *) echo ""; exit 1 ;;
    esac

# Internal helper to setup billing for a project
_setup_billing_for_project PROJECT:
    #!/bin/bash
    
    # First check if we can access billing accounts
    echo "  💳 Looking up available billing accounts..."
    BILLING_ACCOUNTS=$(gcloud billing accounts list --format="value(name)" --filter="open=true" 2>/dev/null)
    
    if [[ -z "$BILLING_ACCOUNTS" ]]; then
        echo "  ❌ No active billing accounts found or insufficient permissions"
        echo "  💡 You need to:"
        echo "     - Create a billing account in Google Cloud Console: https://console.cloud.google.com/billing"
        echo "     - Or get billing admin permissions from your organization"
        echo "     - Then run: gcloud billing projects link {{PROJECT}} --billing-account=BILLING_ACCOUNT_ID"
        echo "  📋 You can list billing accounts with: gcloud billing accounts list"
        exit 1
    fi
    
    # Count billing accounts
    ACCOUNT_COUNT=$(echo "$BILLING_ACCOUNTS" | wc -l | tr -d ' ')
    
    if [[ "$ACCOUNT_COUNT" -eq 1 ]]; then
        # Only one billing account, use it automatically
        BILLING_ACCOUNT=$(echo "$BILLING_ACCOUNTS" | head -1 | sed 's|billingAccounts/||')
        echo "  💡 Found one billing account, using: $BILLING_ACCOUNT"
    else
        # Multiple accounts, let user choose
        echo "  💳 Available billing accounts:"
        gcloud billing accounts list --format="table(name,displayName,open)" --filter="open=true"
        echo
        echo "  💡 You have multiple billing accounts. Please choose one."
        read -p "  Enter your billing account ID (e.g., 01564E-510155-F8E7EB): " BILLING_ACCOUNT
        
        if [[ -z "$BILLING_ACCOUNT" ]]; then
            echo "  ❌ Billing account ID is required"
            echo "  💡 You can set up billing later with:"
            echo "     gcloud billing projects link {{PROJECT}} --billing-account=YOUR_BILLING_ACCOUNT_ID"
            exit 1
        fi
    fi
    
    # Link billing account to project
    echo "  🔗 Linking billing account $BILLING_ACCOUNT to {{PROJECT}}..."
    if gcloud billing projects link "{{PROJECT}}" --billing-account="$BILLING_ACCOUNT"; then
        echo "  ✅ Billing enabled for {{PROJECT}}"
        
        # Verify billing is enabled
        echo "  🔍 Verifying billing status..."
        sleep 2  # Give it a moment to propagate
        BILLING_ENABLED=$(gcloud billing projects describe "{{PROJECT}}" --format="value(billingEnabled)" 2>/dev/null)
        if [[ "$BILLING_ENABLED" == "True" ]]; then
            echo "  ✅ Billing verification successful"
            exit 0
        else
            echo "  ⚠️  Billing may not be fully activated yet (this can take a few minutes)"
            echo "  💡 You can check status later with: gcloud billing projects describe {{PROJECT}}"
            exit 0
        fi
    else
        echo "  ❌ Failed to enable billing for {{PROJECT}}"
        echo "  🔍 Possible reasons:"
        echo "     - Billing account ID '$BILLING_ACCOUNT' is incorrect"
        echo "     - Insufficient billing admin permissions"
        echo "     - Billing account is not active"
        echo "     - Project may be in DELETE_REQUESTED state"
        echo "  💡 Enable billing manually with:"
        echo "     gcloud billing projects link {{PROJECT}} --billing-account=$BILLING_ACCOUNT"
        echo "  📋 List your billing accounts: gcloud billing accounts list"
        exit 1
    fi

# Internal recipe for setting up a single environment
_setup_single_env ENV:
    just _create_env_structure {{ENV}}
    just setup-backend {{ENV}}
    just _create_backend_config {{ENV}}
    just create-provider-config {{ENV}}
    just create-tfvars {{ENV}}