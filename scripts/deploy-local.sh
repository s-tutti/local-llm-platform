#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="llm-platform-local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Deploying LLM Platform to local cluster ==="

# Verify cluster is running
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "ERROR: Cluster '${CLUSTER_NAME}' not found. Run setup-local-cluster.sh first."
  exit 1
fi

# Set kubectl context
kubectl cluster-info --context "kind-${CLUSTER_NAME}" > /dev/null 2>&1

# Build and load API gateway image into Kind
echo "Building API gateway image..."
docker build -t llm-platform/api-gateway:latest "${PROJECT_ROOT}/api-gateway"
kind load docker-image llm-platform/api-gateway:latest --name "$CLUSTER_NAME"

# Apply Kustomize overlay
echo "Applying Kustomize manifests..."
kubectl apply -k "${PROJECT_ROOT}/k8s/overlays/local/"

# Wait for deployments
echo "Waiting for deployments to be ready..."
kubectl -n llm-platform wait --for=condition=Available deployment/ollama --timeout=300s
kubectl -n llm-platform wait --for=condition=Available deployment/api-gateway --timeout=120s

echo ""
echo "=== LLM Platform is running ==="
echo "API Gateway: http://localhost:8080"
echo "Health:      http://localhost:8080/healthz"
echo ""
echo "Pull a model:  kubectl -n llm-platform exec deploy/ollama -- ollama pull phi"
echo "Chat:          curl http://localhost:8080/api/chat -d '{\"model\":\"phi\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}'"
