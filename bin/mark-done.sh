#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# mark-done.sh — Mark a ticket as done after passing acceptance verification
# Usage: harness/bin/mark-done.sh [ticket-id]
# If no ticket-id given, uses current_ticket from QUEUE.json
#
# Flow: verify AC → archive ticket → update queue → update memory → next ticket
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TICKETS_DIR="$PROJECT_ROOT/tickets"
QUEUE="$TICKETS_DIR/QUEUE.json"
MEMORY_DIR="$PROJECT_ROOT/memory"

if [ ! -f "$QUEUE" ]; then
  echo "[ERROR] No QUEUE.json found."
  exit 1
fi

# Get ticket ID
TICKET_ID="${1:-$(jq -r '.current_ticket // empty' "$QUEUE" 2>/dev/null || echo "")}"
if [ -z "$TICKET_ID" ]; then
  echo "[ERROR] No ticket specified and no current ticket."
  echo "Usage: harness/bin/mark-done.sh <ticket-id>"
  exit 1
fi

TICKET_FILE="$TICKETS_DIR/$TICKET_ID.md"
if [ ! -f "$TICKET_FILE" ]; then
  echo "[ERROR] Ticket file not found: $TICKET_FILE"
  exit 1
fi

echo "============================================"
echo "  Marking Done: $TICKET_ID"
echo "============================================"
echo ""

# --- Step 1: Run acceptance verification ---
echo "[1/4] Running acceptance verification..."
VERIFY_SCRIPT="$PROJECT_ROOT/harness/acceptance/verify-all.sh"

if [ -f "$VERIFY_SCRIPT" ]; then
  if ! bash "$VERIFY_SCRIPT" "$TICKET_ID"; then
    echo ""
    echo "[BLOCKED] Acceptance verification failed. Cannot mark done."
    echo "Fix the issues above, then try again."
    exit 2
  fi
  echo "[PASS] All acceptance criteria verified"
else
  echo "[WARN] No verify-all.sh found, skipping AC verification"
fi
echo ""

# --- Step 2: Archive ticket ---
echo "[2/4] Archiving ticket..."
mkdir -p "$TICKETS_DIR/completed"
cp "$TICKET_FILE" "$TICKETS_DIR/completed/$TICKET_ID.md"

# Mark all AC as checked in the archived copy
sed -i 's/- \[ \] /- [x] /g' "$TICKETS_DIR/completed/$TICKET_ID.md"

# Remove from active tickets (use mv as fallback if rm fails in sandboxed environments)
rm "$TICKET_FILE" 2>/dev/null || mv "$TICKET_FILE" "$TICKETS_DIR/completed/.original-$TICKET_ID.md" 2>/dev/null || echo "[WARN] Could not remove original ticket file (sandbox restriction)"
echo "[OK] Archived to tickets/completed/$TICKET_ID.md"
echo ""

# --- Step 3: Update QUEUE.json ---
echo "[3/4] Updating queue..."
NOW=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
TEMP=$(mktemp -p "${PROJECT_ROOT}")

# Get ticket title for progress log
TICKET_TITLE=$(jq -r --arg id "$TICKET_ID" '.queue[] | select(.id==$id) | .title // $id' "$QUEUE" 2>/dev/null || echo "$TICKET_ID")

jq --arg id "$TICKET_ID" --arg now "$NOW" '
  .current_ticket = null |
  (.queue[] | select(.id == $id)) |= (
    .status = "done" |
    .completed_at = $now |
    .archived = true
  )
' "$QUEUE" > "$TEMP" && mv "$TEMP" "$QUEUE"

# Count progress
DONE=$(jq '[.queue[] | select(.status=="done")] | length' "$QUEUE" 2>/dev/null || echo "?")
TOTAL=$(jq '.queue | length' "$QUEUE" 2>/dev/null || echo "?")
echo "[OK] Queue updated ($DONE/$TOTAL complete)"
echo ""

# --- Step 4: Update memory ---
echo "[4/4] Updating memory..."

# Update progress.md
{
  echo ""
  echo "- [$(date -u +'%Y-%m-%d %H:%M:%S')] Completed: $TICKET_ID — $TICKET_TITLE"
} >> "$MEMORY_DIR/progress.md"

# Update daily log
echo "- [$(date -u +'%H:%M:%S')] Completed ticket: $TICKET_ID ($TICKET_TITLE)" >> "$MEMORY_DIR/daily-log.md"

# Update MEMORY.md
TEMP=$(mktemp -p "${PROJECT_ROOT}")
sed "s/\*\*Active Ticket:\*\*.*/\*\*Active Ticket:\*\* None — run next-ticket.sh/" "$MEMORY_DIR/MEMORY.md" > "$TEMP"
mv "$TEMP" "$MEMORY_DIR/MEMORY.md"

echo "[OK] Memory updated"
echo ""

echo "============================================"
echo "  $TICKET_ID DONE ($DONE/$TOTAL)"
echo "============================================"
echo ""
echo "Next: run harness/bin/next-ticket.sh to pick up the next ticket"

exit 0
