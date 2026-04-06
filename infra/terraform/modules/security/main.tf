locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# --- AWS Budgets ---

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-${var.environment}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }

  tags = local.common_tags
}

# --- SSM VPC Endpoints (for private access without bastion) ---

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-${var.environment}-vpce-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.cluster_security_group_id]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpce-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.ap-northeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.ap-northeast-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssm-messages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.ap-northeast-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-ec2-messages-endpoint"
  })
}
