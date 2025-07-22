#!/usr/bin/env python3
"""
Test Script 2: Data Read (READER access required)
This script tests reading transcript data from BigQuery.
Run as: python 02_test_data_read.py --project-id mycompany-mlops-dev
"""

import argparse
from google.cloud import bigquery
from google.cloud.exceptions import GoogleCloudError
import pandas as pd
import sys


def test_data_read(project_id: str, dataset_id: str = "test_data", table_id: str = "transcripts"):
    """Test reading data from the transcripts table."""
    
    print(f"🔍 Testing data read from {project_id}.{dataset_id}.{table_id}")
    print(f"📝 Current user: Check with 'gcloud auth list'\n")
    
    try:
        # Initialize BigQuery client
        client = bigquery.Client(project=project_id)
        
        table_ref = f"{project_id}.{dataset_id}.{table_id}"
        
        # Test 1: Basic SELECT query
        print("📖 Test 1: Basic SELECT query...")
        query = f"""
        SELECT 
            id,
            created_at,
            LENGTH(content) as content_length,
            SUBSTR(content, 1, 50) as content_preview
        FROM `{table_ref}`
        LIMIT 5
        """
        
        df = client.query(query).to_dataframe()
        print(f"✅ SUCCESS: Retrieved {len(df)} rows")
        if not df.empty:
            print("\nSample data:")
            print(df.to_string())
        
        # Test 2: Aggregation query
        print("\n📊 Test 2: Aggregation query...")
        agg_query = f"""
        SELECT 
            DATE(created_at) as date,
            COUNT(*) as transcript_count,
            AVG(LENGTH(content)) as avg_content_length,
            MIN(created_at) as earliest_transcript,
            MAX(created_at) as latest_transcript
        FROM `{table_ref}`
        GROUP BY date
        ORDER BY date DESC
        LIMIT 7
        """
        
        agg_df = client.query(agg_query).to_dataframe()
        print(f"✅ SUCCESS: Retrieved {len(agg_df)} aggregated rows")
        if not agg_df.empty:
            print("\nDaily statistics:")
            print(agg_df.to_string())
        
        # Test 3: Check table metadata
        print("\n🔧 Test 3: Table metadata access...")
        table = client.get_table(table_ref)
        print(f"✅ SUCCESS: Retrieved table metadata")
        print(f"   - Table size: {table.num_rows} rows, {table.num_bytes / 1024:.2f} KB")
        print(f"   - Created: {table.created}")
        print(f"   - Modified: {table.modified}")
        print(f"   - Schema fields: {[field.name for field in table.schema]}")
        
        return True
        
    except GoogleCloudError as e:
        print(f"❌ FAILED: Google Cloud Error")
        print(f"   Error: {e}")
        print(f"\n💡 Possible reasons:")
        print(f"   - You don't have READER access to the dataset")
        print(f"   - You're not in the ml-team@ or analysts@ group")
        print(f"   - The dataset/table doesn't exist yet")
        return False
        
    except Exception as e:
        print(f"❌ FAILED: Unexpected error")
        print(f"   Error: {type(e).__name__}: {e}")
        return False


def test_write_attempt(project_id: str, dataset_id: str = "test_data", table_id: str = "transcripts"):
    """Test if user has write permissions (should fail for read-only users)."""
    
    print(f"\n🚫 Test 4: Attempting write operation (testing read-only access)...")
    
    try:
        client = bigquery.Client(project=project_id)
        table_ref = f"{project_id}.{dataset_id}.{table_id}"
        
        # Try to delete (this should fail for read-only users)
        delete_query = f"""
        DELETE FROM `{table_ref}`
        WHERE id = 'test-delete-attempt'
        """
        
        client.query(delete_query).result()
        print("⚠️  WARNING: Write operation succeeded - user has WRITER access!")
        return True
        
    except Exception as e:
        print("✅ EXPECTED: Write operation failed (read-only access confirmed)")
        print(f"   Error: {str(e)[:100]}...")
        return False


def main():
    parser = argparse.ArgumentParser(description="Test BigQuery data read permissions")
    parser.add_argument("--project-id", required=True, help="GCP Project ID")
    parser.add_argument("--dataset-id", default="test_data", help="BigQuery dataset ID")
    parser.add_argument("--table-id", default="transcripts", help="BigQuery table ID")
    parser.add_argument("--test-write", action="store_true", help="Also test write permissions")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("BigQuery Access Test: Data Read (READER)")
    print("=" * 60)
    
    read_success = test_data_read(args.project_id, args.dataset_id, args.table_id)
    
    if args.test_write and read_success:
        has_write = test_write_attempt(args.project_id, args.dataset_id, args.table_id)
    
    print("\n" + "=" * 60)
    if read_success:
        print("✅ Test PASSED: You have READER access")
        if args.test_write:
            if has_write:
                print("ℹ️  Note: You also have WRITER access")
            else:
                print("ℹ️  Note: You have read-only access (as expected)")
    else:
        print("❌ Test FAILED: You don't have READER access")
    print("=" * 60)
    
    return 0 if read_success else 1


if __name__ == "__main__":
    sys.exit(main())