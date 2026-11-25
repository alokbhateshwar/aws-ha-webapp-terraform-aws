data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # DNS + HTTPS are only enabled when both values are provided.
  enable_dns = var.domain_name != "" && var.hosted_zone_name != ""

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_route53_zone" "this" {
  count        = local.enable_dns ? 1 : 0
  name         = var.hosted_zone_name
  private_zone = false
}

# ---------------------------------------------------------------------------
# 1. Network: VPC, public/private subnets, NAT, S3 endpoint
# ---------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  azs                = local.azs
  single_nat_gateway = var.single_nat_gateway
}

# ---------------------------------------------------------------------------
# 2. Security groups: ALB -> App -> DB (least privilege chain)
# ---------------------------------------------------------------------------
module "security" {
  source = "./modules/security"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  app_port              = var.app_port
  db_port               = 3306
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
  enable_https          = local.enable_dns
}

# ---------------------------------------------------------------------------
# 3. Storage: S3 bucket for static assets
# ---------------------------------------------------------------------------
module "s3" {
  source = "./modules/s3"

  bucket_name   = "${local.name}-assets-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.s3_force_destroy
}

# ---------------------------------------------------------------------------
# 4. Database: RDS MySQL in private DB subnets
# ---------------------------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  name                  = local.name
  subnet_ids            = module.vpc.private_db_subnet_ids
  security_group_id     = module.security.db_sg_id
  db_name               = var.db_name
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  skip_final_snapshot   = var.db_skip_final_snapshot
  deletion_protection   = var.db_deletion_protection
}

# ---------------------------------------------------------------------------
# 5. TLS certificate (optional, only when a domain is configured)
# ---------------------------------------------------------------------------
module "acm" {
  count  = local.enable_dns ? 1 : 0
  source = "./modules/acm"

  domain_name = var.domain_name
  zone_id     = data.aws_route53_zone.this[0].zone_id
}

# ---------------------------------------------------------------------------
# 6. Load balancer in public subnets
# ---------------------------------------------------------------------------
module "alb" {
  source = "./modules/alb"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security.alb_sg_id
  app_port          = var.app_port
  health_check_path = var.health_check_path
  enable_https      = local.enable_dns
  certificate_arn   = one(module.acm[*].certificate_arn)
}

# ---------------------------------------------------------------------------
# 7. Compute: Launch Template + Auto Scaling Group in private app subnets
# ---------------------------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  name               = local.name
  region             = var.aws_region
  subnet_ids         = module.vpc.private_app_subnet_ids
  security_group_id  = module.security.app_sg_id
  target_group_arn   = module.alb.target_group_arn
  instance_type      = var.instance_type
  min_size           = var.asg_min_size
  desired_capacity   = var.asg_desired_capacity
  max_size           = var.asg_max_size
  cpu_target_value   = var.cpu_target_value
  app_port           = var.app_port
  app_code           = file("${path.root}/../app/app.py")
  db_host            = module.rds.address
  db_port            = module.rds.port
  db_name            = module.rds.db_name
  db_secret_arn      = module.rds.secret_arn
  bucket_name        = module.s3.bucket_name
  bucket_arn         = module.s3.bucket_arn
  log_retention_days = var.log_retention_days
  tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# 8. DNS record (optional)
# ---------------------------------------------------------------------------
module "route53" {
  count  = local.enable_dns ? 1 : 0
  source = "./modules/route53"

  zone_id      = data.aws_route53_zone.this[0].zone_id
  domain_name  = var.domain_name
  alb_dns_name = module.alb.dns_name
  alb_zone_id  = module.alb.zone_id
}

# ---------------------------------------------------------------------------
# 9. Monitoring: CloudWatch alarms + dashboard, SNS email alerts
# ---------------------------------------------------------------------------
module "monitoring" {
  source = "./modules/monitoring"

  name                    = local.name
  region                  = var.aws_region
  alert_email             = var.alert_email
  asg_name                = module.compute.asg_name
  alb_arn_suffix          = module.alb.arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  db_identifier           = module.rds.identifier
}
