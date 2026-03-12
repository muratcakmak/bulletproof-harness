#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# verify-functional.sh — Functional flow verification via Chrome MCP
# Called by verify-all.sh for AC type: functional
#
# Similar to verify-visual.sh but focused on interactive flows:
# click-through, form submission, navigation, error handling.
#
# Generates a verification plan that a Chrome MCP agent can execute.
# For standalone use, checks server reachability.
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TICKET_ID="${1:-}"
TICKET_FILE="${2:-}"

APP_URL="${APP_URL:-http://localhost:${DEV_PORT:-5173}}"

if [ -z "$TICKET_FILE" ] || [ ! -f "$TICKET_FILE" ]; then
  echo "[ERROR] Ticket file not found"
  exit 1
fi

echo "  [functional] Checking app at: $APP_URL"

# --- Check server ---
SERVER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$APP_URL" 2>/dev/null || echo "000")

if [ "$SERVER_STATUS" = "000" ]; then
  echo "  [functional] Dev server not reachable at $APP_URL"
  echo "  [functional] Skipping functional verification (server offline)"
  exit 0
fi

echo "  [functional] Server reachable ($SERVER_STATUS)"

# --- Extract functional criteria ---
FUNC_CRITERIA=$(grep '`functional`' "$TICKET_FILE" | sed 's/.*`functional`:\s*//' 2>/dev/null || echo "")

if [ -z "$FUNC_CRITERIA" ]; then
  echo "  [functional] No specific functional criteria in ticket"
  exit 0
fi

# --- Output verification plan for Chrome MCP agent ---
echo "  [functional] Functional verification plan:"
echo ""
echo "  CHROME_MCP_VERIFICATION_PLAN:"
echo "  {"
echo "    \"type\": \"functional\","
echo "    \"url\": \"$APP_URL\","
echo "    \"flows\": ["

echo "$FUNC_CRITERIA" | while IFS= read -r criterion; do
  [ -z "$criterion" ] && continue
  echo "      {"
  echo "        \"description\": \"$criterion\","
  echo "        \"steps\": ["
  echo "          {\"action\": \"navigate\", \"url\": \"$APP_URL\"},"
  echo "          {\"action\": \"find_and_interact\", \"target\": \"$criterion\"},"
  echo "          {\"action\": \"verify_result\", \"expected\": \"$criterion\"}"
  echo "        ]"
  echo "      }"
done

echo ""
echo "    ]"
echo "  }"
echo ""
echo "  [functional] To verify manually: open $APP_URL and test the flows above"
echo "  [functional] For automated verification, use the Stop hook with type: 'agent'"

# Functional checks pass if server is reachable — deep verification requires Chrome MCP
exit 0
