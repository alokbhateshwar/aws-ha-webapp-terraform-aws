resource "aws_db_subnet_group" "this" {
  name        = "${var.name}-db-subnets"
  description = "Private DB subnets"
  subnet_ids  = var.subnet_ids

  tags = { Name = "${var.name}-db-subnets" }
}

resource "aws_db_instance" "this" {
  identifier = "${var.name}-mysql"

  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = "admin"

  # AWS generates the password and stores it in Secrets Manager.
  # Nothing sensitive ever lives in your .tf files or git history.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period = var.backup_retention_days
  backup_window           = "20:00-21:00"         # UTC (01:30-02:30 IST)
  maintenance_window      = "sun:21:30-sun:22:30" # UTC
  copy_tags_to_snapshot   = true

  auto_minor_version_upgrade      = true
  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final-snapshot"
  apply_immediately         = true

  tags = { Name = "${var.name}-mysql" }
}
