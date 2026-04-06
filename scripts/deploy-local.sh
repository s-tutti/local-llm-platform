#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/runtime.sh"

echo "=== Deploying LLM Platform to local cluster (runtime: $RUNTIME) ==="

if ! cluster_exists; then
  echo "ERROR: Cluster '${CLUSTER_NAME}' not found. Run setup-local-cluster.sh first."
  exit 1
fi

cluster_set_context

# Build and load API gateway image
echo "Building API gateway image..."
docker build -t llm-platform/api-gateway:latest "${PROJECT_ROOT}/api-gateway"
echo "Loading image into cluster..."
cluster_load_image llm-platform/api-gateway:latest

# Apply Kustomize overlay
echo "Applying Kustomize manifests..."
kubectl apply -k "${PROJECT_ROOT}/k8s/overlays/local/"

# Wait for deployments
echo "Waiting for deployments to be ready..."
kubectl -n llm-platform wait --for=condition=Available deployment/ollama --timeout=300s
kubectl -n llm-platform wait --for=condition=Available deployment/api-gateway --timeout=120s

echo ""
echo "=== LLM Platform is running ==="
echo "API Gateway:  http://localhost:8080"
echo "Health:       http://localhost:8080/healthz"
echo "Prometheus:   http://localhost:9090"
echo "Grafana:      http://localhost:3000 (admin/admin)"
echo ""
echo "Pull a model:  kubectl -n llm-platform exec deploy/ollama -- ollama pull phi"
echo "Chat:          curl http://localhost:8080/api/chat -d '{\"model\":\"phi\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}'"
