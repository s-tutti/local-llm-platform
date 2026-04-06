# ADR-0003: Zero-trust networking constraints for Terraform
# ADR-0004: FinOps cost optimization constraints
package main

import rego.v1

# ADR-0003: EKS cluster must not have public endpoint
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_eks_cluster"
	resource.change.after.vpc_config[_].endpoint_public_access == true
	msg := sprintf(
		"ERROR: EKS cluster '%s' has public endpoint enabled | WHY: ADR-0003 zero-trust | FIX: Set endpoint_public_access = false",
		[resource.address],
	)
}

# ADR-0003: EKS cluster must have private endpoint
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_eks_cluster"
	resource.change.after.vpc_config[_].endpoint_private_access == false
	msg := sprintf(
		"ERROR: EKS cluster '%s' has private endpoint disabled | WHY: ADR-0003 zero-trust | FIX: Set endpoint_private_access = true",
		[resource.address],
	)
}

# ADR-0003: No wide-open ingress (0.0.0.0/0) on security groups
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_security_group"
	some ingress in resource.change.after.ingress
	some cidr in ingress.cidr_blocks
	cidr == "0.0.0.0/0"
	msg := sprintf(
		"ERROR: Security group '%s' allows ingress from 0.0.0.0/0 | WHY: ADR-0003 zero-trust | FIX: Restrict to specific CIDRs or security group references",
		[resource.address],
	)
}

# ADR-0003: EKS secrets must be encrypted with KMS
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_eks_cluster"
	not has_encryption_config(resource)
	msg := sprintf(
		"ERROR: EKS cluster '%s' missing KMS encryption for secrets | WHY: ADR-0003 data protection | FIX: Add encryption_config with KMS key",
		[resource.address],
	)
}

has_encryption_config(resource) if {
	resource.change.after.encryption_config[_].resources[_] == "secrets"
}

# ADR-0004: GPU node groups must use Spot instances
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_eks_node_group"
	contains(resource.address, "gpu")
	resource.change.after.capacity_type != "SPOT"
	msg := sprintf(
		"ERROR: GPU node group '%s' not using Spot instances | WHY: ADR-0004 FinOps | FIX: Set capacity_type = \"SPOT\"",
		[resource.address],
	)
}

# ADR-0004: Budget alerts must exist
warn contains msg if {
	not has_budget_resource
	msg := "WARN: No aws_budgets_budget resource found | WHY: ADR-0004 FinOps | FIX: Add budget alerts via security module"
}

has_budget_resource if {
	some resource in input.resource_changes
	resource.type == "aws_budgets_budget"
}

# General: VPC flow logs must be enabled
deny contains msg if {
	some resource in input.resource_changes
	resource.type == "aws_vpc"
	not has_flow_log_for_vpc(resource.address)
	msg := sprintf(
		"ERROR: VPC '%s' has no flow log | WHY: ADR-0003 audit trail | FIX: Add aws_flow_log resource for this VPC",
		[resource.address],
	)
}

has_flow_log_for_vpc(vpc_address) if {
	some resource in input.resource_changes
	resource.type == "aws_flow_log"
}
