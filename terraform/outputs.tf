output "app_url" {
  description = "URL to open in your browser."
  value       = local.enable_dns ? "https://${var.domain_name}" : "http://${module.alb.dns_name}"
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = module.alb.dns_name
}

output "asg_name" {
  description = "Auto Scaling Group name."
  value       = module.compute.asg_name
}

output "rds_endpoint" {
  description = "RDS endpoint (private, reachable only from app servers)."
  value       = module.rds.address
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN holding the generated DB credentials."
  value       = module.rds.secret_arn
}

output "s3_bucket_name" {
  description = "S3 bucket for static assets."
  value       = module.s3.bucket_name
}

output "sns_topic_arn" {
  description = "SNS topic used for alarm notifications."
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_dashboard_url" {
  description = "Direct link to the CloudWatch dashboard."
  value       = module.monitoring.dashboard_url
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}
