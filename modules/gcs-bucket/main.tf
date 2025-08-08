 resource "google_storage_bucket" "example_bucket" {
   name     = var.bucket_name
   location = var.region
   force_destroy = true

   labels = var.labels
 }