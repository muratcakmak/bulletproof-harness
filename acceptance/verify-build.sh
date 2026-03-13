#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# verify-build.sh — Build verification (compile + lint + test)
# Called by verify-all.sh for AC type: build
# Exit 0 = pass, Exit 1 = fail
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TICKET_ID="${1:-}"
TICKET_FILE="${2:-}"

cd "$PROJECT_ROOT"

# --- Detect package manager ---
if [ -f "pnpm-lock.yaml" ]; then
  PM="pnpm"
elif [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
  PM="bun"
elif [ -f "yarn.lock" ]; then
  PM="yarn"
elif [ -f "package.json" ]; then
  PM="npm"
else
  echo "[SKIP] No recognized project configuration found"
  exit 0
fi

ERRORS=0

# --- Wrangler env types (before type-check) ---
if [ -f "wrangler.toml" ] || [ -f "wrangler.jsonc" ] || [ -f "wrangler.json" ]; then
  if command -v wrangler &>/dev/null || [ -f "node_modules/.bin/wrangler" ]; then
    echo "  [build] Regenerating Cloudflare env types..."
    if ! npx wrangler types 2>&1 | tail -5; then
      echo "  [build] Warning: wrangler types failed (non-blocking)"
    fi
  fi
fi

# --- Type Check ---
echo "  [build] Running type-check..."

# Check for type-check script
if jq -e '.scripts["type-check"]' package.json &>/dev/null; then
  if ! $PM run type-check 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
elif jq -e '.scripts["typecheck"]' package.json &>/dev/null; then
  if ! $PM run typecheck 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
elif [ -f "tsconfig.json" ]; then
  if ! npx tsc --noEmit 2>&1 | tail -10; then ERRORS=$((ERRORS + 1)); fi
else
  echo "  [build] No TypeScript config found, skipping type-check"
fi

# --- Lint ---
echo "  [build] Running linter..."

if jq -e '.scripts.lint' package.json &>/dev/null; then
  if ! $PM run lint 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
else
  echo "  [build] No lint script found, skipping"
fi

# --- Build ---
echo "  [build] Running build..."

if jq -e '.scripts.build' package.json &>/dev/null; then
  if ! $PM run build 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
fi

# --- Wrangler deploy dry-run (after build) ---
if [ -f "wrangler.toml" ] || [ -f "wrangler.jsonc" ] || [ -f "wrangler.json" ]; then
  if command -v wrangler &>/dev/null || [ -f "node_modules/.bin/wrangler" ]; then
    echo "  [build] Running Wrangler deploy dry-run..."
    if ! npx wrangler deploy --dry-run 2>&1 | tail -5; then
      # Try Pages deploy if standard deploy fails
      if ! npx wrangler pages deploy dist --dry-run 2>&1 | tail -5; then
        echo "  [build] Warning: wrangler deploy dry-run failed"
        ERRORS=$((ERRORS + 1))
      fi
    fi
  fi
fi

# --- Tests ---
echo "  [build] Running tests..."

if jq -e '.scripts.test' package.json &>/dev/null; then
  TEST_OUTPUT=$($PM run test 2>&1 || true)
  EXIT_CODE=$?
  echo "$TEST_OUTPUT" | tail -10
  if [ $EXIT_CODE -ne 0 ]; then ERRORS=$((ERRORS + 1)); fi
else
  echo "  [build] No test script found, skipping"
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "  [build] $ERRORS check(s) failed"
  exit 1
fi

echo "  [build] All checks passed"
exit 0
