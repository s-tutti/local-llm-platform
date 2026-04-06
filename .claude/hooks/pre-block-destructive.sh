#!/usr/bin/env bash
# PreToolUse hook: block destructive commands targeting production
set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$CMD" ]]; then
  exit 0
fi

# Block 1: Direct production terraform apply/destroy
if echo "$CMD" | grep -qE 'terraform\s+(apply|destroy)' && echo "$CMD" | grep -qiE 'prod|production'; then
  jq -n --arg reason "BLOCKED: Direct terraform apply/destroy to production is forbidden. WHY: Production changes must go through CI/CD pipeline (GitHub Actions deploy.yml). FIX: Push to main and use workflow_dispatch with environment=prod." \
    '{"hookSpecificOutput": {"additionalContext": $reason}}'
  exit 2
fi

# Block 2: kubectl delete namespace/deployment in production context
if echo "$CMD" | grep -qE 'kubectl\s+delete\s+(namespace|ns|deployment|deploy|svc|service|pvc|statefulset)' && echo "$CMD" | grep -qiE 'prod|production'; then
  jq -n --arg reason "BLOCKED: kubectl delete on production resources is forbidden. WHY: Destructive operations on production must be reviewed. FIX: Use CI/CD pipeline or get explicit human approval." \
    '{"hookSpecificOutput": {"additionalContext": $reason}}'
  exit 2
fi

# Block 3: rm -rf on critical directories
if echo "$CMD" | grep -qE 'rm\s+-r[f ]*\s*.*(\/|\.\/?)?(infra|k8s|scripts|api-gateway|\.github|\.claude|docs)\b'; then
  jq -n --arg reason "BLOCKED: Recursive delete of project directories is forbidden. WHY: Prevents accidental data loss. FIX: Delete specific files instead, or ask the human." \
    '{"hookSpecificOutput": {"additionalContext": $reason}}'
  exit 2
fi

# Block 4: Database destructive operations
if echo "$CMD" | grep -qiE 'DROP\s+(TABLE|DATABASE|SCHEMA)|TRUNCATE\s+TABLE|DELETE\s+FROM\s+\w+\s*;?\s*$'; then
  jq -n --arg reason "BLOCKED: Destructive database operation detected. WHY: Data loss prevention. FIX: Use migrations with rollback capability." \
    '{"hookSpecificOutput": {"additionalContext": $reason}}'
  exit 2
fi

# Block 5: git force push to main/master
if echo "$CMD" | grep -qE 'git\s+push\s+.*--force' && echo "$CMD" | grep -qE '\b(main|master)\b'; then
  jq -n --arg reason "BLOCKED: Force push to main/master is forbidden. WHY: Rewrites shared history. FIX: Use a feature branch or --force-with-lease." \
    '{"hookSpecificOutput": {"additionalContext": $reason}}'
  exit 2
fi

exit 0
