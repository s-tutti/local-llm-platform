#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="llm-platform-local"

echo "=== Tearing down local LLM Platform ==="

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  kind delete cluster --name "$CLUSTER_NAME"
  echo "Cluster '${CLUSTER_NAME}' deleted."
else
  echo "Cluster '${CLUSTER_NAME}' not found. Nothing to do."
fi
