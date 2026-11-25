variable "name" {
  description = "Name prefix."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
}

variable "azs" {
  description = "List of Availability Zone names."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ."
  type        = bool
  default     = true
}
