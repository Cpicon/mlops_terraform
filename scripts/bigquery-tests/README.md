# BigQuery Access Testing Scripts

This directory contains Python scripts to test BigQuery access permissions for different user scenarios in an ML team.

## Prerequisites

1. Install required Python packages:
```bash
pip install google-cloud-bigquery pandas numpy
```

2. Authenticate with Google Cloud:
```bash
# For personal user account
gcloud auth application-default login

# To check current authentication
gcloud auth list
```

## Scripts Overview

### 1. `01_test_data_upload.py` - Test WRITER Access
Tests the ability to upload transcript data to BigQuery.

**Use Case**: Data scientists uploading training data
```bash
python 01_test_data_upload.py --project-id mycompany-mlops-dev
```

### 2. `02_test_data_read.py` - Test READER Access
Tests the ability to read and query transcript data.

**Use Case**: Analysts running queries and reports
```bash
python 02_test_data_read.py --project-id mycompany-mlops-dev

# Also test if you have write permissions
python 02_test_data_read.py --project-id mycompany-mlops-dev --test-write
```

### 3. `03_test_ml_pipeline.py` - Test ML Pipeline Access
Simulates an ML pipeline that reads, processes, and writes data.

**Use Case**: Automated ML pipelines running as service accounts
```bash
# Run as your user
python 03_test_ml_pipeline.py --project-id mycompany-mlops-dev

# Run as service account
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/ml-pipeline-sa-key.json
python 03_test_ml_pipeline.py --project-id mycompany-mlops-dev --monitor
```

### 4. `04_test_access_summary.py` - Comprehensive Access Report
Generates a detailed report of your BigQuery permissions.

**Use Case**: Debugging access issues
```bash
python 04_test_access_summary.py --project-id mycompany-mlops-dev
```

## Access Scenarios

### Scenario 1: ML Engineer (WRITER Access)
As an ML engineer in the `ml-team@mycompany.com` group:
```bash
# You should be able to:
python 01_test_data_upload.py --project-id mycompany-mlops-dev  # ✅ Pass
python 02_test_data_read.py --project-id mycompany-mlops-dev    # ✅ Pass
python 03_test_ml_pipeline.py --project-id mycompany-mlops-dev  # ✅ Pass
```

### Scenario 2: Data Analyst (READER Access)
As an analyst in the `analysts@mycompany.com` group:
```bash
# You should be able to:
python 02_test_data_read.py --project-id mycompany-mlops-dev    # ✅ Pass
python 01_test_data_upload.py --project-id mycompany-mlops-dev  # ❌ Fail
python 03_test_ml_pipeline.py --project-id mycompany-mlops-dev  # ❌ Fail
```

### Scenario 3: ML Pipeline Service Account
As the `ml-pipeline@` service account:
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json

# You should be able to:
python 01_test_data_upload.py --project-id mycompany-mlops-dev  # ✅ Pass
python 02_test_data_read.py --project-id mycompany-mlops-dev    # ✅ Pass
python 03_test_ml_pipeline.py --project-id mycompany-mlops-dev  # ✅ Pass
```

### Scenario 4: Unauthorized User
As someone not in any authorized group:
```bash
# All operations should fail:
python 04_test_access_summary.py --project-id mycompany-mlops-dev
# Should show: "You have NO ACCESS to this dataset"
```

## Troubleshooting

### No Access Errors
If you get "No Access" errors:

1. **Check authentication**:
```bash
gcloud auth list
gcloud config get-value project
```

2. **Verify dataset exists**:
```bash
# The dataset must be created first via Terraform
cd /path/to/mlops_terraform
just plan dev
just apply dev
```

3. **Check group membership**:
- Ensure your email is in the correct group (ml-team@, analysts@, etc.)
- Or add your email directly to the dataset_access in main.tf

### Permission Denied Errors
If you get "Permission Denied":

1. **For Terraform operations**: You need impersonation rights
```bash
just grant-impersonation dev --user your-email@company.com
```

2. **For data access**: You need to be in the dataset_access list
- Edit `environments/dev/main.tf`
- Add your user/group to the `dataset_access` configuration
- Run `just apply dev` to update permissions

## Testing Different Access Levels

To test as different users:

1. **Switch Google Cloud accounts**:
```bash
gcloud auth application-default login
# Login with different account
```

2. **Use service account**:
```bash
# Create and download service account key
gcloud iam service-accounts keys create key.json \
  --iam-account=ml-pipeline@mycompany-mlops-dev.iam.gserviceaccount.com

# Use it for testing
export GOOGLE_APPLICATION_CREDENTIALS=key.json
python 03_test_ml_pipeline.py --project-id mycompany-mlops-dev

# Clean up
rm key.json
unset GOOGLE_APPLICATION_CREDENTIALS
```

## Important Notes

- **Impersonation vs Data Access**: Terraform impersonation (for infrastructure) is separate from BigQuery data access
- **Dataset must exist**: Run `just apply dev` first to create the BigQuery resources
- **Group membership**: Contact your admin to be added to the appropriate groups
- **Service accounts**: Should be created and granted access via Terraform configuration