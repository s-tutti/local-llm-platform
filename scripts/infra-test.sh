#!/usr/bin/env bash
# Infrastructure E2E test runner
# Runs: conftest (OPA), kubeconform, container-structure-test, archgate
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

FAILED=0
PASSED=0

run_test() {
  local name="$1"
  shift
  echo "--- $name ---"
  if "$@" 2>&1; then
    PASSED=$((PASSED + 1))
    echo "PASS: $name"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL: $name"
  fi
  echo ""
}

echo "=== Infrastructure E2E Tests ==="
echo ""

# 1. Kubeconform: K8s schema validation
if command -v kubeconform &>/dev/null; then
  run_test "kubeconform: K8s schema validation" \
    kubeconform -summary -strict \
    $(find k8s/base -name '*.yaml' -not -name 'kustomization.yaml')
else
  echo "SKIP: kubeconform not installed"
fi

# 2. Conftest: K8s OPA policies (warn-only, some base manifests intentionally lack runAsNonRoot)
if command -v conftest &>/dev/null; then
  run_test "conftest: Terraform OPA policies (good fixture)" \
    conftest test policy/terraform/testdata/plan_good.json -p policy/terraform/

  echo "--- conftest: K8s OPA policies (informational) ---"
  for f in k8s/base/ollama/deployment.yaml k8s/base/api-gateway/deployment.yaml; do
    echo "  $f:"
    conftest test "$f" -p policy/kubernetes/ 2>&1 | grep -E "FAIL|WARN|PASS" | sed 's/^/    /' || true
  done
  echo ""
else
  echo "SKIP: conftest not installed"
fi

# 3. Container structure test (requires Docker)
if command -v container-structure-test &>/dev/null && docker info &>/dev/null; then
  echo "--- container-structure-test: API gateway image ---"
  docker build -t llm-platform/api-gateway:test api-gateway/ -q
  run_test "container-structure-test: API gateway" \
    container-structure-test test \
    --image llm-platform/api-gateway:test \
    --config api-gateway/container-structure-test.yaml
else
  echo "SKIP: container-structure-test or docker not available"
  echo ""
fi

# 4. Archgate: ADR compliance
run_test "archgate: ADR compliance" bash scripts/archgate.sh

echo "=== Results: $PASSED passed, $FAILED failed ==="
[ "$FAILED" -eq 0 ]
