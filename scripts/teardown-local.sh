#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/runtime.sh"

echo "=== Tearing down local LLM Platform (runtime: $RUNTIME) ==="

if cluster_exists; then
  cluster_delete
  echo "Cluster '${CLUSTER_NAME}' deleted."
else
  echo "Cluster '${CLUSTER_NAME}' not found. Nothing to do."
fi
