#!/usr/bin/env python3
"""
Test Script 1: Data Upload (WRITER access required)
This script tests uploading transcript data to BigQuery.
Run as: python 01_test_data_upload.py --project-id mycompany-mlops-dev
"""

import argparse
from datetime import datetime
from google.cloud import bigquery
from google.cloud.exceptions import GoogleCloudError
import uuid
import sys


def test_data_upload(project_id: str, dataset_id: str = "test_data", table_id: str = "transcripts"):
    """Test uploading data to the transcripts table."""
    
    print(f"🔍 Testing data upload to {project_id}.{dataset_id}.{table_id}")
    print(f"📝 Current user: Check with 'gcloud auth list'\n")
    
    try:
        # Initialize BigQuery client
        client = bigquery.Client(project=project_id)
        
        # Prepare test data
        test_rows = [
            {
                "id": str(uuid.uuid4()),
                "created_at": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
                "content": "This is a test transcript for ML training data."
            },
            {
                "id": str(uuid.uuid4()),
                "created_at": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
                "content": "Another test transcript with some technical discussion about machine learning models."
            },
            {
                "id": str(uuid.uuid4()),
                "created_at": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
                "content": "Meeting notes: Discussed the new NLP pipeline architecture and performance metrics."
            }
        ]
        
        # Construct table reference
        table_ref = f"{project_id}.{dataset_id}.{table_id}"
        
        print(f"📤 Attempting to insert {len(test_rows)} rows...")
        
        # Insert rows
        errors = client.insert_rows_json(table_ref, test_rows)
        
        if not errors:
            print("✅ SUCCESS: Data uploaded successfully!")
            print(f"   Inserted {len(test_rows)} rows to {table_ref}")
            
            # Verify by reading back
            query = f"""
            SELECT COUNT(*) as row_count 
            FROM `{table_ref}`
            WHERE DATE(created_at) = CURRENT_DATE()
            """
            
            result = list(client.query(query))
            print(f"   Verified: {result[0].row_count} rows inserted today")
            
        else:
            print("❌ FAILED: Errors occurred during insert:")
            for error in errors:
                print(f"   - {error}")
            return False
            
    except GoogleCloudError as e:
        print(f"❌ FAILED: Google Cloud Error")
        print(f"   Error: {e}")
        print(f"\n💡 Possible reasons:")
        print(f"   - You don't have WRITER access to the dataset")
        print(f"   - You're not in the ml-team@mycompany.com group")
        print(f"   - The dataset/table doesn't exist yet")
        return False
        
    except Exception as e:
        print(f"❌ FAILED: Unexpected error")
        print(f"   Error: {type(e).__name__}: {e}")
        return False
    
    return True


def main():
    parser = argparse.ArgumentParser(description="Test BigQuery data upload permissions")
    parser.add_argument("--project-id", required=True, help="GCP Project ID")
    parser.add_argument("--dataset-id", default="test_data", help="BigQuery dataset ID")
    parser.add_argument("--table-id", default="transcripts", help="BigQuery table ID")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("BigQuery Access Test: Data Upload (WRITER)")
    print("=" * 60)
    
    success = test_data_upload(args.project_id, args.dataset_id, args.table_id)
    
    print("\n" + "=" * 60)
    if success:
        print("✅ Test PASSED: You have WRITER access")
    else:
        print("❌ Test FAILED: You don't have WRITER access")
    print("=" * 60)
    
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())