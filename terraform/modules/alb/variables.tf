variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Public subnet IDs (one per AZ)."
  type        = list(string)
}

variable "security_group_id" {
  type = string
}

variable "app_port" {
  type = number
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "enable_https" {
  description = "Create the 443 listener and redirect 80 -> 443. Must be known at plan time."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN (required when enable_https = true)."
  type        = string
  default     = null
}
