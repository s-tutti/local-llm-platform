#!/usr/bin/env bash
# Stop hook: run archgate ADR compliance check before session ends
# Returns violations as additionalContext so agent sees them before finishing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
RULES_DIR="$PROJECT_ROOT/docs/adr/.rules"

VIOLATIONS=""
FAILED=0

for rule_file in "$RULES_DIR"/ADR-*.ts; do
  [ -f "$rule_file" ] || continue
  OUTPUT=$(npx --yes tsx "$rule_file" "$PROJECT_ROOT" 2>&1) || {
    FAILED=$((FAILED + 1))
    VIOLATIONS="${VIOLATIONS}${OUTPUT}\n"
  }
done

if [ "$FAILED" -gt 0 ]; then
  MSG=$(printf "ARCHGATE VIOLATION: %d ADR rule(s) failed before session end. Fix these before declaring work complete:\n%b" "$FAILED" "$VIOLATIONS")
  jq -n --arg ctx "$MSG" \
    '{"hookSpecificOutput": {"hookEventName": "Stop", "additionalContext": $ctx}}'
  exit 2
fi

exit 0
