 variable "bucket_name" {
   description = "The name of the bucket"
   type        = string
 }

 variable "region" {
   description = "The region where the bucket will be created"
   type        = string
 }

 variable "labels" {
   description = "Labels applied to the bucket"
   type        = map(string)
   default     = {}
 }