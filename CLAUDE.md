# Local LLM Platform

## Project Overview
Enterprise-grade IaC platform for running LLMs in closed networks.

## Structure
- `docs/adr/` — Architecture Decision Records
- `infra/terraform/` — AWS infrastructure (VPC, EKS, security)
- `k8s/` — Kubernetes manifests (Kustomize: base + overlays)
- `scripts/` — Local dev environment scripts (Kind cluster)
- `api-gateway/` — Lightweight API proxy for Ollama
- `.github/workflows/` — CI/CD pipelines

## Commands
- Local cluster: `./scripts/setup-local-cluster.sh`
- Deploy locally: `./scripts/deploy-local.sh`
- Teardown: `./scripts/teardown-local.sh`
- Terraform validate: `cd infra/terraform/environments/dev && terraform init && terraform validate`
- K8s lint: `kubectl kustomize k8s/overlays/local/`

## Conventions
- Terraform: modules under `infra/terraform/modules/`, environments bind variables
- K8s: Kustomize base + overlays pattern, no Helm (keep it simple)
- ADRs: numbered `NNNN-title.md` format
- All resources namespaced under `llm-platform`
