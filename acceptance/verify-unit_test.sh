#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# verify-unit_test.sh — Unit test verification
# Called by verify-all.sh for AC type: unit_test
# Runs the project's test suite or specific test files mentioned in the ticket
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="${HARNESS_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$HARNESS_DIR/.." && pwd)}"
TICKET_ID="${1:-}"
TICKET_FILE="${2:-}"

cd "$PROJECT_ROOT"

# --- Detect package manager ---
if [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
elif [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then PM="bun"
elif [ -f "yarn.lock" ]; then PM="yarn"
elif [ -f "package.json" ]; then PM="npm"
else
  echo "  [unit_test] No package.json found"
  exit 0
fi

# --- Detect @cloudflare/vitest-pool-workers ---
if [ -f "package.json" ] && jq -e '.devDependencies["@cloudflare/vitest-pool-workers"] // .dependencies["@cloudflare/vitest-pool-workers"]' package.json &>/dev/null; then
  echo "  [unit_test] Detected @cloudflare/vitest-pool-workers — tests run in Workers runtime"
fi

# --- Extract specific test files from ticket (if mentioned) ---
SPECIFIC_TESTS=""
if [ -n "$TICKET_FILE" ] && [ -f "$TICKET_FILE" ]; then
  SPECIFIC_TESTS=$(grep -oE '[^[:space:]]+\.(test|spec)\.(ts|tsx|js|jsx)' "$TICKET_FILE" 2>/dev/null | sort -u || echo "")
fi

echo "  [unit_test] Running tests..."

if [ -n "$SPECIFIC_TESTS" ]; then
  echo "  [unit_test] Found specific test files in ticket:"
  ERRORS=0

  for TEST_FILE in $SPECIFIC_TESTS; do
    # Try to find the file
    FOUND=$(find "$PROJECT_ROOT" -path "*/node_modules" -prune -o -name "$(basename "$TEST_FILE")" -print 2>/dev/null | head -1)

    if [ -n "$FOUND" ]; then
      echo "  [unit_test] Running: $FOUND"
      if ! $PM run test -- "$FOUND" 2>&1 | tail -10; then
        ERRORS=$((ERRORS + 1))
      fi
    else
      echo "  [unit_test] File not found: $TEST_FILE (may not be created yet)"
      ERRORS=$((ERRORS + 1))
    fi
  done

  if [ "$ERRORS" -gt 0 ]; then
    echo "  [unit_test] $ERRORS test file(s) failed"
    exit 1
  fi
else
  # Run full test suite
  if jq -e '.scripts.test' package.json &>/dev/null; then
    if ! $PM run test 2>&1 | tail -15; then
      echo "  [unit_test] Test suite failed"
      exit 1
    fi
  else
    echo "  [unit_test] No test script in package.json"
    exit 0
  fi
fi

echo "  [unit_test] All tests passed"
exit 0
