#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# post-edit-typecheck.sh — PostToolUse hook (Edit|Write)
# Fires after: Edit or Write tool completes
# Purpose: Auto-run type-check on code files to catch errors early
# Exit 0 = pass, Exit 2 = block (tells Claude to fix)
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Read hook input from stdin
INPUT=$(cat 2>/dev/null || echo '{}')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# Only check code files
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.mts|*.cts)
    # TypeScript/JavaScript — run type-check
    ;;
  */wrangler.toml|*/wrangler.jsonc|*/wrangler.json)
    # Wrangler config changed — regenerate env types
    cd "$PROJECT_ROOT"
    if command -v wrangler &>/dev/null || [ -f "node_modules/.bin/wrangler" ]; then
      echo "[HARNESS] Wrangler config changed, regenerating env types..." >&2
      npx wrangler types 2>&1 | tail -5 || true
    fi
    exit 0
    ;;
  *)
    # Not a code file, skip
    exit 0
    ;;
esac

cd "$PROJECT_ROOT"

# --- Detect and run type checker ---

# TypeScript project
if [ -f "tsconfig.json" ] || [ -f "tsconfig.base.json" ]; then
  # Find the right type-check command
  if [ -f "package.json" ]; then
    # Check for type-check script in package.json
    HAS_TYPECHECK=$(jq -r '.scripts["type-check"] // .scripts["typecheck"] // empty' package.json 2>/dev/null || echo "")

    if [ -n "$HAS_TYPECHECK" ]; then
      # Detect package manager
      if [ -f "pnpm-lock.yaml" ]; then
        PM="pnpm"
      elif [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
        PM="bun"
      elif [ -f "yarn.lock" ]; then
        PM="yarn"
      else
        PM="npm"
      fi

      # Run type-check (capture output, limit to 20 lines)
      OUTPUT=$($PM run type-check 2>&1 || $PM run typecheck 2>&1 || true)
      EXIT_CODE=$?
    else
      # Fallback: run tsc directly
      if command -v npx &>/dev/null; then
        OUTPUT=$(npx tsc --noEmit 2>&1 || true)
        EXIT_CODE=$?
      elif command -v tsc &>/dev/null; then
        OUTPUT=$(tsc --noEmit 2>&1 || true)
        EXIT_CODE=$?
      else
        # No TypeScript compiler found, skip
        exit 0
      fi
    fi

    if [ $EXIT_CODE -ne 0 ]; then
      echo "[HARNESS] TypeScript errors detected after editing $FILE_PATH:" >&2
      echo "$OUTPUT" | head -20 >&2
      echo "" >&2
      echo "[HARNESS] Fix these errors before proceeding." >&2
      # Exit 2 = block, stderr shown to Claude
      exit 2
    fi
  fi
fi

# All checks passed
exit 0
