variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "app_port" {
  type = number
}

variable "db_port" {
  type    = number
  default = 3306
}

variable "allowed_ingress_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "enable_https" {
  description = "Also open port 443 on the ALB."
  type        = bool
  default     = false
}
