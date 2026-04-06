# K8s manifest policy checks
# ADR-0001: No external LLM endpoints
# ADR-0002: Base manifests must be environment-neutral
# General: Security best practices
package main

import rego.v1

# Containers must not run as root
deny contains msg if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.securityContext.runAsNonRoot
	# Only flag if no pod-level security context either
	not input.spec.template.spec.securityContext.runAsNonRoot
	msg := sprintf(
		"ERROR: Container '%s' in Deployment '%s' may run as root | WHY: Security best practice | FIX: Set securityContext.runAsNonRoot = true",
		[container.name, input.metadata.name],
	)
}

# Containers must have resource limits
deny contains msg if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.resources.limits
	msg := sprintf(
		"ERROR: Container '%s' in Deployment '%s' has no resource limits | WHY: Prevent resource exhaustion | FIX: Add resources.limits for cpu and memory",
		[container.name, input.metadata.name],
	)
}

# Containers must have resource requests
deny contains msg if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.resources.requests
	msg := sprintf(
		"ERROR: Container '%s' in Deployment '%s' has no resource requests | WHY: Scheduler needs hints for placement | FIX: Add resources.requests for cpu and memory",
		[container.name, input.metadata.name],
	)
}

# All resources must be namespaced under llm-platform
deny contains msg if {
	input.metadata.namespace
	input.metadata.namespace != "llm-platform"
	not input.kind == "ClusterRole"
	not input.kind == "ClusterRoleBinding"
	msg := sprintf(
		"ERROR: %s '%s' uses namespace '%s' | WHY: All resources must be in 'llm-platform' namespace | FIX: Set metadata.namespace = 'llm-platform'",
		[input.kind, input.metadata.name, input.metadata.namespace],
	)
}

# Containers must have liveness probes
warn contains msg if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.livenessProbe
	msg := sprintf(
		"WARN: Container '%s' in Deployment '%s' has no livenessProbe | WHY: K8s cannot detect hung processes | FIX: Add livenessProbe",
		[container.name, input.metadata.name],
	)
}

# Containers must have readiness probes
warn contains msg if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	not container.readinessProbe
	msg := sprintf(
		"WARN: Container '%s' in Deployment '%s' has no readinessProbe | WHY: Traffic may route to unready pods | FIX: Add readinessProbe",
		[container.name, input.metadata.name],
	)
}

# Images should not use :latest tag in production overlay
deny contains msg if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	endswith(container.image, ":latest")
	msg := sprintf(
		"WARN: Container '%s' uses :latest tag | WHY: Non-deterministic deploys | FIX: Pin to a specific version or SHA",
		[container.name],
	)
}

# ADR-0001: No external LLM API URLs in env vars
deny contains msg if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
	some env_var in container.env
	is_external_llm_url(env_var.value)
	msg := sprintf(
		"ERROR: Env var '%s' in container '%s' points to external LLM API | WHY: ADR-0001 data sovereignty | FIX: Use internal Ollama service URL",
		[env_var.name, container.name],
	)
}

is_external_llm_url(val) if contains(val, "api.openai.com")
is_external_llm_url(val) if contains(val, "api.anthropic.com")
is_external_llm_url(val) if contains(val, "generativelanguage.googleapis.com")

# Services: NodePort range must match Kind port mappings
warn contains msg if {
	input.kind == "Service"
	input.spec.type == "NodePort"
	some port in input.spec.ports
	port.nodePort
	not valid_nodeport(port.nodePort)
	msg := sprintf(
		"WARN: Service '%s' uses nodePort %d which is not in Kind port mappings (30080, 30090, 30030) | WHY: Won't be accessible locally | FIX: Use a mapped port or add to Kind config",
		[input.metadata.name, port.nodePort],
	)
}

valid_nodeport(p) if p == 30080
valid_nodeport(p) if p == 30090
valid_nodeport(p) if p == 30030
