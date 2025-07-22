#!/usr/bin/env python3
"""
Test Script 3: ML Pipeline Service Account Access
This script simulates an ML pipeline processing transcripts.
Run as: python 03_test_ml_pipeline.py --project-id mycompany-mlops-dev
"""

import argparse
from datetime import datetime, timedelta
from google.cloud import bigquery
from google.cloud.exceptions import GoogleCloudError
import pandas as pd
import numpy as np
import sys
import json


def simulate_ml_processing(df: pd.DataFrame) -> pd.DataFrame:
    """Simulate ML processing on transcript data."""
    
    # Simulate some ML features
    df['word_count'] = df['content'].str.split().str.len()
    df['char_count'] = df['content'].str.len()
    df['avg_word_length'] = df['char_count'] / df['word_count']
    df['sentiment_score'] = np.random.uniform(-1, 1, len(df))  # Simulated sentiment
    df['topic_confidence'] = np.random.uniform(0.5, 1.0, len(df))  # Simulated topic model
    df['processing_timestamp'] = datetime.utcnow()
    
    # Simulate topic classification
    topics = ['technical', 'business', 'general', 'support']
    df['predicted_topic'] = np.random.choice(topics, len(df))
    
    return df


def test_ml_pipeline(project_id: str, dataset_id: str = "test_data"):
    """Test ML pipeline operations: read, process, and write back."""
    
    print(f"🤖 Testing ML pipeline access for {project_id}.{dataset_id}")
    print(f"📝 Current identity: Check with 'gcloud auth list'\n")
    
    try:
        # Initialize BigQuery client
        client = bigquery.Client(project=project_id)
        
        source_table = f"{project_id}.{dataset_id}.transcripts"
        processed_table = f"{project_id}.{dataset_id}.transcripts_processed"
        
        # Step 1: Read recent transcripts for processing
        print("📥 Step 1: Reading transcripts for processing...")
        read_query = f"""
        SELECT 
            id,
            created_at,
            content
        FROM `{source_table}`
        WHERE created_at >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 30 DAY)
        """
        
        df = client.query(read_query).to_dataframe()
        print(f"✅ Retrieved {len(df)} transcripts for processing")
        
        if df.empty:
            print("⚠️  No data to process. Generating sample data...")
            # Create sample data for testing
            df = pd.DataFrame({
                'id': [f'ml-test-{i}' for i in range(5)],
                'created_at': [datetime.utcnow() - timedelta(days=i) for i in range(5)],
                'content': [
                    "Technical discussion about neural networks and deep learning.",
                    "Business meeting notes on Q4 revenue projections.",
                    "General team standup discussing project timelines.",
                    "Customer support ticket regarding login issues.",
                    "Technical deep dive into transformer architecture."
                ]
            })
        
        # Step 2: Process data (simulate ML pipeline)
        print("\n🔬 Step 2: Processing transcripts through ML pipeline...")
        processed_df = simulate_ml_processing(df)
        print(f"✅ Processed {len(processed_df)} transcripts")
        print("\nSample processed data:")
        print(processed_df[['id', 'predicted_topic', 'sentiment_score', 'word_count']].head())
        
        # Step 3: Write results back to BigQuery
        print(f"\n📤 Step 3: Writing processed results to {processed_table}...")
        
        # Define schema for processed table
        job_config = bigquery.LoadJobConfig(
            schema=[
                bigquery.SchemaField("id", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("created_at", "DATETIME", mode="REQUIRED"),
                bigquery.SchemaField("content", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("word_count", "INTEGER"),
                bigquery.SchemaField("char_count", "INTEGER"),
                bigquery.SchemaField("avg_word_length", "FLOAT"),
                bigquery.SchemaField("sentiment_score", "FLOAT"),
                bigquery.SchemaField("topic_confidence", "FLOAT"),
                bigquery.SchemaField("predicted_topic", "STRING"),
                bigquery.SchemaField("processing_timestamp", "DATETIME"),
            ],
            write_disposition="WRITE_TRUNCATE",  # Replace table contents
        )
        
        # Load data to BigQuery
        job = client.load_table_from_dataframe(
            processed_df, 
            processed_table, 
            job_config=job_config
        )
        job.result()  # Wait for job to complete
        
        print(f"✅ Successfully wrote {len(processed_df)} processed records")
        
        # Step 4: Verify and summarize
        print("\n📊 Step 4: Generating processing summary...")
        summary_query = f"""
        SELECT 
            predicted_topic,
            COUNT(*) as count,
            AVG(sentiment_score) as avg_sentiment,
            AVG(word_count) as avg_words
        FROM `{processed_table}`
        GROUP BY predicted_topic
        ORDER BY count DESC
        """
        
        summary_df = client.query(summary_query).to_dataframe()
        print("\nProcessing Summary by Topic:")
        print(summary_df.to_string())
        
        return True
        
    except GoogleCloudError as e:
        print(f"❌ FAILED: Google Cloud Error")
        print(f"   Error: {e}")
        print(f"\n💡 Possible reasons:")
        print(f"   - Service account doesn't have WRITER access")
        print(f"   - Not running with ml-pipeline@ service account")
        print(f"   - Tables don't exist yet")
        print(f"\n📝 To run as service account:")
        print(f"   1. Create and download SA key")
        print(f"   2. export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json")
        print(f"   3. Run this script again")
        return False
        
    except Exception as e:
        print(f"❌ FAILED: Unexpected error")
        print(f"   Error: {type(e).__name__}: {e}")
        return False


def test_pipeline_monitoring(project_id: str, dataset_id: str = "test_data"):
    """Test pipeline monitoring queries."""
    
    print(f"\n📈 Testing pipeline monitoring capabilities...")
    
    try:
        client = bigquery.Client(project=project_id)
        
        # Check processing history
        monitor_query = f"""
        SELECT 
            DATE(processing_timestamp) as process_date,
            COUNT(DISTINCT id) as transcripts_processed,
            COUNT(DISTINCT predicted_topic) as unique_topics,
            MIN(processing_timestamp) as first_process_time,
            MAX(processing_timestamp) as last_process_time
        FROM `{project_id}.{dataset_id}.transcripts_processed`
        WHERE processing_timestamp >= DATETIME_SUB(CURRENT_DATETIME(), INTERVAL 7 DAY)
        GROUP BY process_date
        ORDER BY process_date DESC
        """
        
        monitor_df = client.query(monitor_query).to_dataframe()
        
        if not monitor_df.empty:
            print("✅ Pipeline monitoring data available:")
            print(monitor_df.to_string())
        else:
            print("ℹ️  No recent processing history found")
            
        return True
        
    except Exception as e:
        print(f"⚠️  Monitoring query failed: {str(e)[:100]}...")
        return False


def main():
    parser = argparse.ArgumentParser(description="Test ML pipeline BigQuery access")
    parser.add_argument("--project-id", required=True, help="GCP Project ID")
    parser.add_argument("--dataset-id", default="test_data", help="BigQuery dataset ID")
    parser.add_argument("--monitor", action="store_true", help="Also run monitoring queries")
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("BigQuery Access Test: ML Pipeline (WRITER)")
    print("=" * 60)
    
    success = test_ml_pipeline(args.project_id, args.dataset_id)
    
    if args.monitor and success:
        test_pipeline_monitoring(args.project_id, args.dataset_id)
    
    print("\n" + "=" * 60)
    if success:
        print("✅ Test PASSED: ML pipeline has required access")
    else:
        print("❌ Test FAILED: ML pipeline lacks required access")
    print("=" * 60)
    
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())