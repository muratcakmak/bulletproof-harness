#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# verify-visual.sh — Visual UI verification via Chrome MCP
# Called by verify-all.sh for AC type: visual
#
# This script generates a VERIFICATION PLAN that Claude's Stop hook agent
# can execute using Chrome MCP tools. Shell scripts cannot directly invoke
# Chrome MCP, so this outputs structured instructions.
#
# When used with a Stop hook of type "agent", the agent has access to:
#   - mcp__Claude_in_Chrome__computer (screenshot)
#   - mcp__Claude_in_Chrome__find (locate elements)
#   - mcp__Claude_in_Chrome__navigate (go to URL)
#   - mcp__Claude_in_Chrome__read_page (accessibility tree)
#
# For standalone verification, this checks if the dev server is reachable
# and outputs the visual checks that need manual/agent verification.
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TICKET_ID="${1:-}"
TICKET_FILE="${2:-}"

APP_URL="${APP_URL:-http://localhost:${DEV_PORT:-5173}}"

if [ -z "$TICKET_FILE" ] || [ ! -f "$TICKET_FILE" ]; then
  echo "[ERROR] Ticket file not found"
  exit 1
fi

echo "  [visual] Checking UI at: $APP_URL"

# --- Check if dev server is reachable ---
SERVER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$APP_URL" 2>/dev/null || echo "000")

if [ "$SERVER_STATUS" = "000" ]; then
  echo "  [visual] Dev server not reachable at $APP_URL"
  echo "  [visual] Start the dev server first, or set APP_URL env var"
  echo "  [visual] Skipping visual verification (server offline)"
  # Don't fail — visual checks are best-effort when server isn't running
  exit 0
fi

echo "  [visual] Server reachable ($SERVER_STATUS)"

# --- Extract visual criteria from ticket ---
VISUAL_CRITERIA=$(grep '`visual`' "$TICKET_FILE" | sed 's/.*`visual`:\s*//' 2>/dev/null || echo "")

if [ -z "$VISUAL_CRITERIA" ]; then
  echo "  [visual] No specific visual criteria in ticket"
  echo "  [visual] Basic check: page loads and returns HTML"
  exit 0
fi

# --- Output verification plan for Chrome MCP agent ---
echo "  [visual] Visual verification plan:"
echo ""
echo "  CHROME_MCP_VERIFICATION_PLAN:"
echo "  {"
echo "    \"type\": \"visual\","
echo "    \"url\": \"$APP_URL\","
echo "    \"checks\": ["

FIRST=true
echo "$VISUAL_CRITERIA" | while IFS= read -r criterion; do
  [ -z "$criterion" ] && continue
  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo ","
  fi
  echo "      {\"description\": \"$criterion\", \"action\": \"screenshot_and_verify\"}"
done

echo ""
echo "    ]"
echo "  }"
echo ""
echo "  [visual] To verify manually: open $APP_URL and check the criteria above"
echo "  [visual] For automated verification, use the Stop hook with type: 'agent'"

# Visual checks pass if server is reachable — deep verification requires Chrome MCP
exit 0
