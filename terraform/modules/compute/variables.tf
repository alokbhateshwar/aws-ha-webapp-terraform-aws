variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_ids" {
  description = "Private app subnet IDs (one per AZ)."
  type        = list(string)
}

variable "security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "min_size" {
  type    = number
  default = 2
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 4
}

variable "cpu_target_value" {
  type    = number
  default = 50
}

variable "app_port" {
  type = number
}

variable "app_code" {
  description = "Contents of app/app.py, embedded in user data."
  type        = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "bucket_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
