locals {
  alb_ports = var.enable_https ? [80, 443] : [80]

  # every (port, cidr) combination for the ALB ingress rules
  alb_ingress = {
    for pair in setproduct(local.alb_ports, var.allowed_ingress_cidrs) :
    "${pair[0]}-${pair[1]}" => { port = pair[0], cidr = pair[1] }
  }
}

# ---------------------------------------------------------------------------
# ALB security group: internet -> ALB
# ---------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Public load balancer"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_in" {
  for_each = local.alb_ingress

  security_group_id = aws_security_group.alb.id
  description       = "Web traffic from allowed CIDRs"
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to app servers only"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

# ---------------------------------------------------------------------------
# App security group: ALB -> EC2. No SSH; use SSM Session Manager instead.
# ---------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.name}-app-sg"
  description = "Application servers"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App traffic from the ALB only"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS out (package install, AWS APIs, SSM) via NAT / S3 endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "MySQL to the database tier"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.db.id
}

# ---------------------------------------------------------------------------
# DB security group: EC2 -> RDS only
# ---------------------------------------------------------------------------
resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Database tier"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from app servers only"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.app.id
}
