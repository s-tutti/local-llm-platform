#!/usr/bin/env bash
# Archgate: Run all ADR companion rule checks
# Usage: ./scripts/archgate.sh [project-root]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${1:-$(dirname "$SCRIPT_DIR")}"
RULES_DIR="$PROJECT_ROOT/docs/adr/.rules"

echo "=== Archgate: ADR Compliance Check ==="
echo ""

FAILED=0
PASSED=0
TOTAL=0

for rule_file in "$RULES_DIR"/ADR-*.ts; do
  [ -f "$rule_file" ] || continue
  TOTAL=$((TOTAL + 1))
  RULE_NAME=$(basename "$rule_file" .ts)

  if npx tsx "$rule_file" "$PROJECT_ROOT" 2>&1; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=== Results: $PASSED/$TOTAL passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
