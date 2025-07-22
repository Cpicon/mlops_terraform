#!/usr/bin/env python3
"""
Test Script 4: Comprehensive Access Summary
This script tests all access levels and provides a summary report.
Run as: python 04_test_access_summary.py --project-id mycompany-mlops-dev
"""

import argparse
from google.cloud import bigquery
from google.api_core import exceptions
import sys
from typing import Dict, List, Tuple
import json


def check_dataset_permissions(client: bigquery.Client, project_id: str, dataset_id: str) -> Dict[str, bool]:
    """Check various permissions on the dataset."""
    
    permissions = {
        'dataset_exists': False,
        'can_list_tables': False,
        'can_get_dataset': False,
        'can_create_table': False,
        'can_read_data': False,
        'can_write_data': False,
        'can_delete_data': False,
        'can_update_dataset': False
    }
    
    dataset_ref = f"{project_id}.{dataset_id}"
    
    # Check if dataset exists and is accessible
    try:
        dataset = client.get_dataset(dataset_ref)
        permissions['dataset_exists'] = True
        permissions['can_get_dataset'] = True
    except exceptions.NotFound:
        print(f"❌ Dataset {dataset_ref} not found")
        return permissions
    except exceptions.Forbidden:
        print(f"❌ No access to dataset {dataset_ref}")
        return permissions
    
    # Check table listing
    try:
        tables = list(client.list_tables(dataset_ref))
        permissions['can_list_tables'] = True
    except:
        pass
    
    # Check data read
    try:
        query = f"SELECT 1 FROM `{dataset_ref}.transcripts` LIMIT 1"
        list(client.query(query))
        permissions['can_read_data'] = True
    except:
        pass
    
    # Check data write
    try:
        test_table = f"{dataset_ref}.access_test_temp"
        query = f"CREATE OR REPLACE TABLE `{test_table}` AS SELECT 'test' as data"
        client.query(query).result()
        permissions['can_create_table'] = True
        permissions['can_write_data'] = True
        
        # Clean up
        client.delete_table(test_table, not_found_ok=True)
    except:
        pass
    
    # Check data delete
    try:
        query = f"DELETE FROM `{dataset_ref}.transcripts` WHERE id = 'nonexistent-test-id'"
        client.query(query).result()
        permissions['can_delete_data'] = True
    except:
        pass
    
    # Check dataset update
    try:
        dataset.description = dataset.description  # No actual change
        client.update_dataset(dataset, ["description"])
        permissions['can_update_dataset'] = True
    except:
        pass
    
    return permissions


def get_current_user_info(client: bigquery.Client) -> Tuple[str, str]:
    """Get information about the current authenticated user."""
    
    try:
        # Try to get the current user from application default credentials
        import google.auth
        credentials, project = google.auth.default()
        
        if hasattr(credentials, 'service_account_email'):
            return 'service_account', credentials.service_account_email
        elif hasattr(credentials, '_service_account_email'):
            return 'service_account', credentials._service_account_email
        else:
            # For user credentials, we can't easily get the email
            return 'user', 'Current user (run: gcloud auth list)'
    except:
        return 'unknown', 'Unable to determine'


def check_iam_roles(client: bigquery.Client, project_id: str) -> List[str]:
    """Check project-level IAM roles (requires resourcemanager permissions)."""
    
    roles = []
    try:
        # This requires additional permissions that users might not have
        # Including for reference but will likely fail for most users
        from google.cloud import resourcemanager_v3
        
        rm_client = resourcemanager_v3.ProjectsClient()
        project_name = f"projects/{project_id}"
        
        # This would get IAM policy but requires admin permissions
        # policy = rm_client.get_iam_policy(resource=project_name)
        # ... parse policy for current user's roles
        
        roles.append("Unable to check project IAM (requires admin permissions)")
    except:
        roles.append("Unable to check project IAM (requires admin permissions)")
    
    return roles


def generate_access_report(project_id: str, dataset_id: str = "test_data"):
    """Generate a comprehensive access report."""
    
    print(f"🔍 Generating access report for {project_id}.{dataset_id}")
    print("=" * 60)
    
    client = bigquery.Client(project=project_id)
    
    # Get user info
    auth_type, identity = get_current_user_info(client)
    print(f"\n👤 Current Identity:")
    print(f"   Type: {auth_type}")
    print(f"   Identity: {identity}")
    
    # Check permissions
    print(f"\n🔐 Permission Check Results:")
    permissions = check_dataset_permissions(client, project_id, dataset_id)
    
    for perm, has_access in permissions.items():
        status = "✅" if has_access else "❌"
        perm_display = perm.replace('_', ' ').title()
        print(f"   {status} {perm_display}")
    
    # Determine access level
    print(f"\n📊 Access Level Summary:")
    if permissions['can_update_dataset'] and permissions['can_delete_data']:
        access_level = "OWNER"
        print(f"   🔑 You have OWNER access (full control)")
    elif permissions['can_write_data'] and permissions['can_create_table']:
        access_level = "WRITER"
        print(f"   ✏️  You have WRITER access (can read and modify data)")
    elif permissions['can_read_data']:
        access_level = "READER"
        print(f"   👁️  You have READER access (read-only)")
    else:
        access_level = "NONE"
        print(f"   🚫 You have NO ACCESS to this dataset")
    
    # Recommendations
    print(f"\n💡 Recommendations:")
    if access_level == "NONE":
        print(f"   1. Ensure the dataset exists: just apply dev")
        print(f"   2. Request access from admin: add your email/group to dataset_access in main.tf")
        print(f"   3. Check if you're authenticated: gcloud auth list")
    elif access_level == "READER":
        print(f"   - You can run analytics and reports")
        print(f"   - For write access, request WRITER role from admin")
    elif access_level == "WRITER":
        print(f"   - You can read/write data and create tables")
        print(f"   - You cannot modify dataset properties or permissions")
    else:  # OWNER
        print(f"   - You have full control over this dataset")
        print(f"   - Be careful with destructive operations")
    
    # Test queries based on access level
    if permissions['can_read_data']:
        print(f"\n📝 Sample Queries You Can Run:")
        
        print(f"\n-- Count transcripts:")
        print(f"SELECT COUNT(*) FROM `{project_id}.{dataset_id}.transcripts`")
        
        if permissions['can_write_data']:
            print(f"\n-- Insert new transcript:")
            print(f"INSERT INTO `{project_id}.{dataset_id}.transcripts`")
            print(f"VALUES ('id123', CURRENT_DATETIME(), 'Your content here')")
            
            print(f"\n-- Create new table:")
            print(f"CREATE TABLE `{project_id}.{dataset_id}.your_table`")
            print(f"AS SELECT * FROM `{project_id}.{dataset_id}.transcripts`")
    
    return access_level != "NONE"


def main():
    parser = argparse.ArgumentParser(description="Generate comprehensive BigQuery access report")
    parser.add_argument("--project-id", required=True, help="GCP Project ID")
    parser.add_argument("--dataset-id", default="test_data", help="BigQuery dataset ID")
    parser.add_argument("--json", action="store_true", help="Output results as JSON")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("BigQuery Access Report")
    print("=" * 60)
    
    try:
        has_access = generate_access_report(args.project_id, args.dataset_id)
        return 0 if has_access else 1
    except Exception as e:
        print(f"\n❌ Failed to generate report: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())