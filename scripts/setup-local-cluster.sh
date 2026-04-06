#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/runtime.sh"

echo "=== Local LLM Platform Setup (runtime: $RUNTIME) ==="

check_prerequisites

if cluster_exists; then
  echo "Cluster '${CLUSTER_NAME}' already exists. Use teardown-local.sh to remove it first."
  exit 0
fi

echo "Creating cluster..."
cluster_create

echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo ""
echo "=== Cluster '${CLUSTER_NAME}' is ready ==="
echo "Run './scripts/deploy-local.sh' to deploy the LLM platform."
