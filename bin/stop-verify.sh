#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# stop-verify.sh — Stop hook
# Fires when: Claude finishes responding (every response)
# Purpose: Check if there's an active ticket with unverified AC
# Exit 0 = allow stop, Exit 2 = block (tell Claude what's not done)
#
# IMPORTANT: This hook fires on EVERY response, not just task completion.
# We check if Claude is actively working a ticket before enforcing AC.
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QUEUE="$PROJECT_ROOT/tickets/QUEUE.json"
TICKETS_DIR="$PROJECT_ROOT/tickets"

# Read hook input
INPUT=$(cat 2>/dev/null || echo '{}')

# Check if this is a stop_hook_active (prevent infinite loop)
IS_STOP_HOOK=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
if [ "$IS_STOP_HOOK" = "true" ]; then
  exit 0
fi

# Check if there's an active ticket
if [ ! -f "$QUEUE" ]; then
  exit 0
fi

CURRENT_TICKET=$(jq -r '.current_ticket // empty' "$QUEUE" 2>/dev/null || echo "")
if [ -z "$CURRENT_TICKET" ]; then
  exit 0  # No active ticket, allow stop
fi

TICKET_FILE="$TICKETS_DIR/$CURRENT_TICKET.md"
if [ ! -f "$TICKET_FILE" ]; then
  exit 0
fi

# Check ticket status — only enforce for in_progress tickets
TICKET_STATUS=$(jq -r --arg id "$CURRENT_TICKET" '.queue[] | select(.id==$id) | .status' "$QUEUE" 2>/dev/null || echo "")
if [ "$TICKET_STATUS" != "in_progress" ]; then
  exit 0
fi

# --- Check if AC criteria exist and are unchecked ---
# Look for unchecked items in Acceptance Criteria section
AC_UNCHECKED=$(awk '/## Acceptance Criteria/,/^## [^A]/' "$TICKET_FILE" | grep -c '^\- \[ \]' 2>/dev/null || echo "0")

if [ "$AC_UNCHECKED" -gt 0 ]; then
  echo "============================================" >&2
  echo "  HARNESS — Acceptance Criteria Not Met" >&2
  echo "============================================" >&2
  echo "" >&2
  echo "Ticket $CURRENT_TICKET has $AC_UNCHECKED unchecked acceptance criteria:" >&2
  echo "" >&2
  awk '/## Acceptance Criteria/,/^## [^A]/' "$TICKET_FILE" | grep '^\- \[ \]' >&2
  echo "" >&2
  echo "Before marking this ticket done:" >&2
  echo "  1. Verify each criterion above" >&2
  echo "  2. Run: harness/bin/verify-all.sh $CURRENT_TICKET" >&2
  echo "  3. Mark done: harness/bin/mark-done.sh $CURRENT_TICKET" >&2
  echo "" >&2
  echo "If you're not done with this ticket yet, continue working." >&2
  echo "If you're blocked, update bugs: harness/bin/update-memory.sh bugs 'description'" >&2
  echo "============================================" >&2

  # Exit 2 = block stop, stderr shown to Claude
  exit 2
fi

# All AC checked, allow stop
exit 0
