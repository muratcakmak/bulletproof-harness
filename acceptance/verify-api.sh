#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# verify-api.sh — API endpoint verification
# Called by verify-all.sh for AC type: api
#
# Parses AC lines from the ticket for API criteria and tests them.
# Format in ticket: - [ ] `api`: METHOD /path returns STATUS
#
# Requires: curl, jq
# Assumes dev server is running on localhost
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="${HARNESS_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$HARNESS_DIR/.." && pwd)}"
TICKET_ID="${1:-}"
TICKET_FILE="${2:-}"

# Default API base URL (override with API_BASE env var)
API_BASE="${API_BASE:-http://localhost:${PORT:-8788}}"

if [ -z "$TICKET_FILE" ] || [ ! -f "$TICKET_FILE" ]; then
  echo "[ERROR] Ticket file not found"
  exit 1
fi

echo "  [api] Testing against: $API_BASE"

# --- Extract API criteria ---
# Look for patterns like: GET /api/users returns 200
# or: POST /api/auth/login returns 201
API_CRITERIA=$(grep -i '`api`' "$TICKET_FILE" | grep -oiE '(GET|POST|PUT|DELETE|PATCH)[[:space:]]+/[^[:space:]]+[[:space:]]+returns?[[:space:]]+[0-9]+' 2>/dev/null || echo "")

if [ -z "$API_CRITERIA" ]; then
  # No parseable API criteria, try a basic health check
  echo "  [api] No specific API criteria found in ticket."
  echo "  [api] Attempting basic connectivity check..."

  # Try common health endpoints
  for ENDPOINT in "/health" "/api/health" "/healthz" "/"; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$API_BASE$ENDPOINT" 2>/dev/null || echo "000")
    if [ "$STATUS" != "000" ]; then
      echo "  [api] $ENDPOINT → $STATUS (server reachable)"
      exit 0
    fi
  done

  echo "  [api] Could not reach server at $API_BASE"
  echo "  [api] Make sure the dev server is running."
  echo "  [api] Hint: try 'wrangler pages dev' or 'pnpm dev'"
  exit 1
fi

ERRORS=0
CHECKS=0

echo "$API_CRITERIA" | while IFS= read -r line; do
  [ -z "$line" ] && continue
  CHECKS=$((CHECKS + 1))

  METHOD=$(echo "$line" | grep -oiE '(GET|POST|PUT|DELETE|PATCH)' | head -1 | tr '[:lower:]' '[:upper:]')
  PATH=$(echo "$line" | grep -oE '/[^[:space:]]+' | head -1)
  EXPECTED=$(echo "$line" | grep -oE '[0-9]{3}' | tail -1)

  if [ -z "$METHOD" ] || [ -z "$PATH" ] || [ -z "$EXPECTED" ]; then
    echo "  [api] Could not parse: $line"
    continue
  fi

  URL="$API_BASE$PATH"
  ACTUAL=$(curl -s -o /dev/null -w "%{http_code}" -X "$METHOD" --connect-timeout 5 "$URL" 2>/dev/null || echo "000")

  if [ "$ACTUAL" = "$EXPECTED" ]; then
    echo "  [api] $METHOD $PATH → $ACTUAL (expected $EXPECTED) ✓"
  else
    echo "  [api] $METHOD $PATH → $ACTUAL (expected $EXPECTED) ✗"
    ERRORS=$((ERRORS + 1))
  fi
done

# The pipe creates a subshell, so we check differently
FINAL_ERRORS=$(echo "$API_CRITERIA" | while IFS= read -r line; do
  [ -z "$line" ] && continue
  METHOD=$(echo "$line" | grep -oiE '(GET|POST|PUT|DELETE|PATCH)' | head -1 | tr '[:lower:]' '[:upper:]')
  PATH=$(echo "$line" | grep -oE '/[^[:space:]]+' | head -1)
  EXPECTED=$(echo "$line" | grep -oE '[0-9]{3}' | tail -1)
  [ -z "$METHOD" ] || [ -z "$PATH" ] || [ -z "$EXPECTED" ] && continue
  URL="$API_BASE$PATH"
  ACTUAL=$(curl -s -o /dev/null -w "%{http_code}" -X "$METHOD" --connect-timeout 5 "$URL" 2>/dev/null || echo "000")
  [ "$ACTUAL" != "$EXPECTED" ] && echo "FAIL"
done | grep -c "FAIL" 2>/dev/null || echo "0")

if [ "$FINAL_ERRORS" -gt 0 ]; then
  echo "  [api] $FINAL_ERRORS endpoint(s) failed"
  exit 1
fi

echo "  [api] All API checks passed"
exit 0
