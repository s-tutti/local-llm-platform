#!/usr/bin/env bash
# PreToolUse hook: protect linter/formatter config files from agent modification
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Protected config files — agents must not modify these
PROTECTED_FILES=(
  "pyproject.toml"
  "ruff.toml"
  ".yamllint.yml"
  ".yamllint.yaml"
  "biome.json"
  ".eslintrc"
  ".eslintrc.json"
  ".prettierrc"
  ".tfsec.yml"
  ".trivyignore"
)

for PROTECTED in "${PROTECTED_FILES[@]}"; do
  if [[ "$BASENAME" == "$PROTECTED" ]]; then
    jq -n --arg reason "BLOCKED: Cannot modify $BASENAME — linter/formatter configs are protected. WHY: Agents must not weaken or disable lint rules (ADR convention). If a rule is wrong, ask the human to update it." \
      '{"hookSpecificOutput": {"additionalContext": $reason}}'
    exit 2
  fi
done

exit 0
