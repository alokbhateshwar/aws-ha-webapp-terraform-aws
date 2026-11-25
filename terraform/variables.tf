# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1" # Mumbai
}

variable "project_name" {
  description = "Short lowercase project name, used as a prefix for all resources."
  type        = string
  default     = "ha-webapp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project_name))
    error_message = "project_name must be 3-20 chars: lowercase letters, digits, hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name (dev, stage, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.environment))
    error_message = "environment must be 2-8 lowercase letters/digits."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread across (2 or 3)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 for high availability."
  }
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheap, lab use). false = one NAT per AZ (production HA)."
  type        = bool
  default     = true
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the load balancer."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# Application / compute
# ---------------------------------------------------------------------------
variable "app_port" {
  description = "Port the application listens on (EC2 instances)."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "ALB target group health check path."
  type        = string
  default     = "/health"
}

variable "instance_type" {
  description = "EC2 instance type for application servers."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of instances (keep >= 2 for HA)."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Initial desired number of instances."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "Target average CPU % for the Auto Scaling target-tracking policy."
  type        = number
  default     = 50
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 14
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------
variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "MySQL engine version (major.minor or just major)."
  type        = string
  default     = "8.0"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "appdb"
}

variable "db_allocated_storage" {
  description = "Initial DB storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Upper limit for RDS storage autoscaling in GiB."
  type        = number
  default     = 50
}

variable "db_multi_az" {
  description = "Enable Multi-AZ standby for RDS. Set true for production-grade HA (extra cost)."
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Automated backup retention in days."
  type        = number
  default     = 7
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on destroy. Keep true for labs, false for production."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Protect the DB from accidental deletion. Set true for production."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------
variable "alert_email" {
  description = "Email address that receives SNS alarm notifications (you must confirm the subscription)."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

# ---------------------------------------------------------------------------
# DNS / HTTPS (optional)
# ---------------------------------------------------------------------------
variable "domain_name" {
  description = "Full domain for the app, e.g. app.example.com. Leave empty to skip Route 53 + HTTPS and use the ALB DNS name."
  type        = string
  default     = ""
}

variable "hosted_zone_name" {
  description = "Existing Route 53 public hosted zone, e.g. example.com. Required when domain_name is set."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# S3
# ---------------------------------------------------------------------------
variable "s3_force_destroy" {
  description = "Allow terraform destroy to delete a non-empty S3 bucket. Keep true for labs."
  type        = bool
  default     = true
}
