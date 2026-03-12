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
elif [ -f "Cargo.toml" ]; then
  PM="cargo"
elif [ -f "go.mod" ]; then
  PM="go"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
  PM="python"
else
  echo "[SKIP] No recognized project configuration found"
  exit 0
fi

ERRORS=0

# --- Type Check ---
echo "  [build] Running type-check..."

case "$PM" in
  npm|pnpm|yarn|bun)
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
    ;;
  cargo)
    if ! cargo check 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
    ;;
  go)
    if ! go vet ./... 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
    ;;
  python)
    if command -v mypy &>/dev/null; then
      if ! mypy . 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
    fi
    ;;
esac

# --- Lint ---
echo "  [build] Running linter..."

case "$PM" in
  npm|pnpm|yarn|bun)
    if jq -e '.scripts.lint' package.json &>/dev/null; then
      if ! $PM run lint 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
    else
      echo "  [build] No lint script found, skipping"
    fi
    ;;
  cargo)
    if ! cargo clippy 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
    ;;
  go)
    if command -v golangci-lint &>/dev/null; then
      if ! golangci-lint run 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
    fi
    ;;
  python)
    if command -v ruff &>/dev/null; then
      if ! ruff check . 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
    fi
    ;;
esac

# --- Build ---
echo "  [build] Running build..."

case "$PM" in
  npm|pnpm|yarn|bun)
    if jq -e '.scripts.build' package.json &>/dev/null; then
      if ! $PM run build 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
    fi
    ;;
  cargo)
    if ! cargo build 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
    ;;
  go)
    if ! go build ./... 2>&1 | tail -5; then ERRORS=$((ERRORS + 1)); fi
    ;;
esac

# --- Tests ---
echo "  [build] Running tests..."

case "$PM" in
  npm|pnpm|yarn|bun)
    if jq -e '.scripts.test' package.json &>/dev/null; then
      TEST_OUTPUT=$($PM run test 2>&1 || true)
      EXIT_CODE=$?
      echo "$TEST_OUTPUT" | tail -10
      if [ $EXIT_CODE -ne 0 ]; then ERRORS=$((ERRORS + 1)); fi
    else
      echo "  [build] No test script found, skipping"
    fi
    ;;
  cargo)
    if ! cargo test 2>&1 | tail -10; then ERRORS=$((ERRORS + 1)); fi
    ;;
  go)
    if ! go test ./... 2>&1 | tail -10; then ERRORS=$((ERRORS + 1)); fi
    ;;
  python)
    if command -v pytest &>/dev/null; then
      if ! pytest 2>&1 | tail -10; then ERRORS=$((ERRORS + 1)); fi
    fi
    ;;
esac

if [ "$ERRORS" -gt 0 ]; then
  echo "  [build] $ERRORS check(s) failed"
  exit 1
fi

echo "  [build] All checks passed"
exit 0
