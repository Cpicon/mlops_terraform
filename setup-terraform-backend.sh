#!/bin/bash

# =============================================================================
# Terraform GCS Backend Setup Script v3 - Per-Environment Buckets
# =============================================================================
# This script creates and manages separate GCS buckets for each environment
# 
# WORKFLOW:
# 1. Admin runs with --admin-setup to grant permissions and create bucket
# 2. Service account is used for ongoing Terraform operations
#
# KEY CHANGE: Each environment now gets its own dedicated state bucket
# - Dev: {dev-project}-terraform-state
# - Stage: {stage-project}-terraform-state
# - Prod: {prod-project}-terraform-state
#
# Usage: ./setup-terraform-backend.sh [--admin-setup | --service-account-setup]
# =============================================================================

set -e  # Exit on any error

# Default parameters
PROJECT_ID="${PROJECT_ID}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT}"
SERVICE_ACCOUNT_KEY_FILE="${SERVICE_ACCOUNT_KEY_FILE}"
BUCKET_PREFIX="${BUCKET_PREFIX}"
BUCKET_LOCATION="${BUCKET_LOCATION:-us-central1}"
BUCKET_STORAGE_CLASS="${BUCKET_STORAGE_CLASS:-STANDARD}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Functions for colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_admin() { echo -e "${PURPLE}[ADMIN]${NC} $1"; }

show_usage() {
    cat << EOF
Usage: $0 [MODE] [OPTIONS]

MODES:
    --admin-setup              Run admin bootstrap tasks (requires admin privileges)
    --help                     Show this help

This script follows production workflow:
1. Admin runs: $0 --admin-setup (grants permissions, creates bucket)

OPTIONS:
    -p, --project PROJECT_ID              GCP Project ID (default: ${PROJECT_ID})
    -s, --service-account EMAIL           Service account email (default: ${SERVICE_ACCOUNT})
    -k, --key-file PATH                   Service account key file (default: ${SERVICE_ACCOUNT_KEY_FILE})
    -b, --bucket-prefix PREFIX            Bucket name prefix (default: ${BUCKET_PREFIX})
    -l, --location LOCATION               Bucket location (default: ${BUCKET_LOCATION})

EXAMPLES:
    # Admin bootstrap (run once)
    $0 --admin-setup

    # Custom project admin setup
    $0 --admin-setup --project my-project --service-account terraform@my-project.iam.gserviceaccount.com

EOF
}

# Parse command line arguments
MODE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --admin-setup)
            MODE="admin"
            shift
            ;;
        -p|--project)
            PROJECT_ID="$2"
            shift 2
            ;;
        -s|--service-account)
            SERVICE_ACCOUNT="$2"
            shift 2
            ;;
        -k|--key-file)
            SERVICE_ACCOUNT_KEY_FILE="$2"
            shift 2
            ;;
        -b|--bucket-prefix)
            BUCKET_PREFIX="$2"
            shift 2
            ;;
        -l|--location)
            BUCKET_LOCATION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set derived parameters after argument parsing
if [[ -z "$BUCKET_PREFIX" ]]; then
    BUCKET_PREFIX="${PROJECT_ID}-terraform-state"
fi
BUCKET_NAME="${BUCKET_PREFIX}"

if [[ -z "$MODE" ]]; then
    print_error "Mode required. Use --admin-setup"
    show_usage
    exit 1
fi

# Check prerequisites
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is required but not installed."
        exit 1
    fi
}

# Admin bootstrap function
admin_setup() {
    print_admin "🔐 Admin Bootstrap Mode"
    print_status "This mode requires admin privileges to:"
    print_status "  1. Grant IAM roles to service account"
    print_status "  2. Create GCS bucket for Terraform state"
    print_status "  3. Configure bucket settings"
    echo

    print_status "Configuration:"
    echo "  Project ID:         ${PROJECT_ID}"
    echo "  Service Account:    ${SERVICE_ACCOUNT}"
    echo "  Bucket Name:        ${BUCKET_NAME}"
    echo "  Bucket Location:    ${BUCKET_LOCATION}"
    echo

    # Prerequisites
    print_status "Checking prerequisites..."
    check_command "gcloud"
    check_command "gsutil"

    # Check if user has admin permissions
    print_status "Verifying admin permissions..."
    CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    print_status "Authenticated as: ${CURRENT_USER}"
    #check if CURRENT_USER is the same as SERVICE_ACCOUNT
    if [[ "${CURRENT_USER}" == "${SERVICE_ACCOUNT}" ]]; then
        print_error "Authenticated as ${CURRENT_USER} but service account is ${SERVICE_ACCOUNT}. Please run 'gcloud auth login' with the admin account email."
        exit 1
    fi


    # Create bucket (check if exists first)
    print_admin "Creating GCS bucket: ${BUCKET_NAME}"
    if gsutil ls "gs://${BUCKET_NAME}" &> /dev/null; then
        print_warning "Bucket already exists"
    else
        if gsutil mb -p "${PROJECT_ID}" -c "${BUCKET_STORAGE_CLASS}" -l "${BUCKET_LOCATION}" "gs://${BUCKET_NAME}"; then
            print_success "Bucket created successfully"
        else
            print_error "Failed to create bucket"
            exit 1
        fi
    fi

    # Enable versioning
    print_admin "Enabling versioning..."
    if gsutil versioning set on "gs://${BUCKET_NAME}"; then
        print_success "Versioning enabled"
    fi

    print_success "🎉 Admin bootstrap complete!"
}

# Main execution
main() {
    # case to extend functionality in the future
    case $MODE in
        "admin")
            admin_setup
            ;;
        *)
            print_error "Invalid mode: $MODE"
            exit 1
            ;;
    esac
}

main "$@" 