#!/usr/bin/env bash
# PostToolUse hook: language-specific linting after Write/Edit
# Returns JSON with hookSpecificOutput.additionalContext for agent feedback
set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

EXT="${FILE_PATH##*.}"
BASENAME=$(basename "$FILE_PATH")
ERRORS=""

case "$EXT" in
  py)
    if command -v ruff &>/dev/null; then
      # Auto-fix formatting first
      ruff format "$FILE_PATH" 2>/dev/null || true
      # Then check for remaining violations
      LINT_OUT=$(ruff check "$FILE_PATH" 2>&1) || true
      # Filter out "All checks passed!" — that means no violations
      if [[ -n "$LINT_OUT" ]] && ! echo "$LINT_OUT" | grep -q "^All checks passed"; then
        ERRORS="ERROR: Ruff violations found | $FILE_PATH | WHY: Python style/correctness (see pyproject.toml) | FIX: Review and fix the following:\n$LINT_OUT"
      fi
    fi
    ;;
  tf)
    if command -v terraform &>/dev/null; then
      DIR=$(dirname "$FILE_PATH")
      FMT_OUT=$(terraform fmt -check -diff "$FILE_PATH" 2>&1) || true
      if [[ -n "$FMT_OUT" ]]; then
        terraform fmt "$FILE_PATH" 2>/dev/null || true
        ERRORS="ERROR: Terraform format violation (auto-fixed) | $FILE_PATH | WHY: Canonical HCL formatting (ADR convention) | FIX: File has been auto-formatted by terraform fmt"
      fi
    fi
    ;;
  yaml|yml)
    if command -v yamllint &>/dev/null; then
      LINT_OUT=$(yamllint -d relaxed "$FILE_PATH" 2>&1) || true
      if echo "$LINT_OUT" | grep -q "error"; then
        ERRORS="ERROR: YAML lint violations | $FILE_PATH | WHY: Valid YAML structure required for K8s manifests | FIX: Fix the following:\n$LINT_OUT"
      fi
    fi
    ;;
  sh|bash)
    # Basic syntax check (shellcheck not always available)
    SYNTAX_OUT=$(bash -n "$FILE_PATH" 2>&1) || true
    if [[ -n "$SYNTAX_OUT" ]]; then
      ERRORS="ERROR: Shell syntax error | $FILE_PATH | WHY: Scripts must be syntactically valid | FIX: Fix the following:\n$SYNTAX_OUT"
    fi
    if command -v shellcheck &>/dev/null; then
      SC_OUT=$(shellcheck -f gcc "$FILE_PATH" 2>&1) || true
      if [[ -n "$SC_OUT" ]]; then
        ERRORS="${ERRORS:+$ERRORS\n}ERROR: ShellCheck violations | $FILE_PATH | WHY: Shell best practices | FIX:\n$SC_OUT"
      fi
    fi
    ;;
  Dockerfile|dockerfile)
    # Basic Dockerfile syntax: ensure FROM exists
    if [[ "$BASENAME" == "Dockerfile" ]] || [[ "$BASENAME" == dockerfile* ]]; then
      if ! grep -qi '^FROM' "$FILE_PATH"; then
        ERRORS="ERROR: Dockerfile missing FROM instruction | $FILE_PATH | WHY: Every Dockerfile must start with FROM | FIX: Add a FROM instruction"
      fi
    fi
    ;;
esac

if [[ -n "$ERRORS" ]]; then
  # Return structured feedback for agent context
  jq -n --arg ctx "$(echo -e "$ERRORS")" \
    '{"hookSpecificOutput": {"additionalContext": $ctx}}'
  exit 1
fi

exit 0
