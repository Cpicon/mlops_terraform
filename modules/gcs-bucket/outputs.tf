 output "bucket_url" {
   description = "The URL of the bucket"
   value       = google_storage_bucket.example_bucket.url
 }