# Latest Amazon Linux 2023 AMI, resolved through the public SSM parameter
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------------------------
# CloudWatch log group (application + bootstrap logs shipped by the agent)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.name}/app"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------------------
# IAM role for the EC2 instances (no static credentials anywhere)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Session Manager: shell access without SSH keys or open port 22
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch agent: push logs + memory/disk metrics
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Least privilege: read ONE secret, use ONE bucket
data "aws_iam_policy_document" "app_access" {
  statement {
    sid       = "ReadDbSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }

  statement {
    sid       = "ListAssetsBucket"
    actions   = ["s3:ListBucket"]
    resources = [var.bucket_arn]
  }

  statement {
    sid       = "ObjectAccessAssetsBucket"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "app_access" {
  name   = "${var.name}-app-access"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app_access.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.app.name
}

# ---------------------------------------------------------------------------
# Launch template
# ---------------------------------------------------------------------------
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-lt-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = [var.security_group_id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    app_code      = var.app_code
    app_port      = var.app_port
    region        = var.region
    db_host       = var.db_host
    db_port       = var.db_port
    db_name       = var.db_name
    db_secret_arn = var.db_secret_arn
    bucket_name   = var.bucket_name
    log_group     = aws_cloudwatch_log_group.app.name
  }))

  # IMDSv2 only (blocks SSRF-style credential theft)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }

  update_default_version = true

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# Auto Scaling Group spread across private app subnets (one per AZ)
# ---------------------------------------------------------------------------
resource "aws_autoscaling_group" "app" {
  name                = "${var.name}-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB" # replace instances the load balancer marks unhealthy
  health_check_grace_period = 300

  # Publish per-group metrics (shown on the dashboard)
  metrics_granularity = "1Minute"
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances",
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # Changing the launch template rolls instances one batch at a time
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name}-app" })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity] # the scaling policy owns this value
  }
}

# Scale out/in automatically to keep average CPU near the target
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.cpu_target_value
  }
}
