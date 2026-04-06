variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 500
}

variable "alert_email" {
  description = "Email address for budget and security alerts"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for SSM VPC endpoints"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for VPC endpoints"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  type        = string
}
