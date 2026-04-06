#!/usr/bin/env bash
# PreToolUse hook: block writes to secret/credential files
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Pattern-based secret file detection
BLOCKED=false
REASON=""

# Exact filename matches
case "$BASENAME" in
  .env|.env.local|.env.production|.env.staging|.env.development)
    BLOCKED=true
    REASON="environment variable file"
    ;;
  credentials|credentials.json|service-account.json)
    BLOCKED=true
    REASON="credential file"
    ;;
  id_rsa|id_ed25519|id_ecdsa)
    BLOCKED=true
    REASON="SSH private key"
    ;;
  *.pem|*.key|*.p12|*.pfx)
    BLOCKED=true
    REASON="certificate/key file"
    ;;
esac

# Path-based checks
if [[ "$FILE_PATH" == *".ssh/"* ]]; then
  BLOCKED=true
  REASON="SSH directory"
fi

if [[ "$FILE_PATH" == *"aws/credentials"* || "$FILE_PATH" == *".aws/"* ]]; then
  BLOCKED=true
  REASON="AWS credentials"
fi

if [[ "$FILE_PATH" == *"kube/config"* || "$FILE_PATH" == *".kube/"* ]]; then
  BLOCKED=true
  REASON="kubeconfig"
fi

if [[ "$BLOCKED" == "true" ]]; then
  jq -n --arg reason "BLOCKED: Cannot write to $BASENAME ($REASON). WHY: Secret/credential files must never be created or modified by agents. FIX: Manage secrets manually or via a secrets manager." \
    '{"hookSpecificOutput": {"additionalContext": $reason}}'
  exit 2
fi

exit 0
