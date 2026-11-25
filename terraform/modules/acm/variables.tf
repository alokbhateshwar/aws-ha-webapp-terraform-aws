variable "domain_name" {
  type = string
}

variable "zone_id" {
  description = "Route 53 hosted zone ID used for DNS validation."
  type        = string
}
