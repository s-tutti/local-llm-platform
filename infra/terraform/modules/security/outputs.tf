output "budget_id" {
  description = "ID of the AWS Budget"
  value       = aws_budgets_budget.monthly.id
}

output "vpc_endpoint_sg_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}
