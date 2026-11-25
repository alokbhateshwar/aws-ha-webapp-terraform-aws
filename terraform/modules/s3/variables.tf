variable "bucket_name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "force_destroy" {
  description = "Delete all objects when the bucket is destroyed."
  type        = bool
  default     = true
}
