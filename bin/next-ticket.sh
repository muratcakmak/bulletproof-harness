#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# next-ticket.sh — Pick up the next ready ticket from the queue
# Updates QUEUE.json: sets current_ticket, status → in_progress
# Prints the ticket content to stdout for context
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TICKETS_DIR="$PROJECT_ROOT/tickets"
QUEUE="$TICKETS_DIR/QUEUE.json"
MEMORY_DIR="$PROJECT_ROOT/memory"

if [ ! -f "$QUEUE" ]; then
  echo "[ERROR] No QUEUE.json found. Run harness/bin/generate-tickets.sh first."
  exit 1
fi

# Check if there's already a ticket in progress
CURRENT=$(jq -r '.current_ticket // empty' "$QUEUE" 2>/dev/null || echo "")
if [ -n "$CURRENT" ]; then
  CURRENT_STATUS=$(jq -r --arg id "$CURRENT" '.queue[] | select(.id==$id) | .status' "$QUEUE" 2>/dev/null || echo "")
  if [ "$CURRENT_STATUS" = "in_progress" ]; then
    echo "[INFO] Ticket already in progress: $CURRENT"
    echo ""
    if [ -f "$TICKETS_DIR/$CURRENT.md" ]; then
      cat "$TICKETS_DIR/$CURRENT.md"
    fi
    exit 0
  fi
fi

# --- Promote backlog tickets whose dependencies are met ---
# Build a list of done ticket numbers for dependency matching
DONE_NUMS=$(jq -r '.queue[] | select(.status=="done") | .id | split("-")[0] | tonumber | tostring' "$QUEUE" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

# Use bash loop for reliable dependency checking
TEMP=$(mktemp -p "${PROJECT_ROOT}")
cp "$QUEUE" "$TEMP"

for ROW_IDX in $(jq -r 'range(.queue | length)' "$QUEUE"); do
  STATUS=$(jq -r ".queue[$ROW_IDX].status" "$QUEUE")
  if [ "$STATUS" != "backlog" ]; then continue; fi

  DEPS=$(jq -r ".queue[$ROW_IDX].depends_on // [] | .[]" "$QUEUE" 2>/dev/null)
  if [ -z "$DEPS" ]; then
    # No dependencies → promote to ready
    jq ".queue[$ROW_IDX].status = \"ready\"" "$TEMP" > "${TEMP}.2" && mv "${TEMP}.2" "$TEMP"
    continue
  fi

  ALL_MET=true
  for DEP in $DEPS; do
    DEP_NUM=$(echo "$DEP" | sed 's/^0*//' | sed 's/-.*//')
    [ -z "$DEP_NUM" ] && DEP_NUM="0"
    if ! echo ",$DONE_NUMS," | grep -q ",$DEP_NUM,"; then
      ALL_MET=false
      break
    fi
  done

  if [ "$ALL_MET" = true ]; then
    jq ".queue[$ROW_IDX].status = \"ready\"" "$TEMP" > "${TEMP}.2" && mv "${TEMP}.2" "$TEMP"
  fi
done

mv "$TEMP" "$QUEUE"

# --- Find next ready ticket ---
NEXT_TICKET=$(jq -r '[.queue[] | select(.status=="ready")] | first | .id // empty' "$QUEUE" 2>/dev/null || echo "")

if [ -z "$NEXT_TICKET" ]; then
  # Check if everything is done
  REMAINING=$(jq '[.queue[] | select(.status != "done")] | length' "$QUEUE" 2>/dev/null || echo "0")
  if [ "$REMAINING" -eq 0 ]; then
    echo "============================================"
    echo "  ALL TICKETS COMPLETE!"
    echo "============================================"
    echo ""
    TOTAL=$(jq '.queue | length' "$QUEUE" 2>/dev/null || echo "0")
    echo "Finished $TOTAL tickets."
  else
    echo "[INFO] No ready tickets. $REMAINING tickets remaining (blocked or backlog)."
    echo ""
    echo "Blocked/backlog tickets:"
    jq -r '.queue[] | select(.status != "done") | "  " + .id + " (" + .status + ")" + if .depends_on then " depends: " + (.depends_on | join(", ")) else "" end' "$QUEUE" 2>/dev/null
  fi
  exit 0
fi

# --- Assign the ticket ---
NOW=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
TEMP=$(mktemp -p "${PROJECT_ROOT}")
jq --arg id "$NEXT_TICKET" --arg now "$NOW" '
  .current_ticket = $id |
  (.queue[] | select(.id == $id)) |= (.status = "in_progress" | .assigned_at = $now)
' "$QUEUE" > "$TEMP" && mv "$TEMP" "$QUEUE"

echo "============================================"
echo "  ASSIGNED: $NEXT_TICKET"
echo "============================================"
echo ""

# Print ticket content
TICKET_FILE="$TICKETS_DIR/$NEXT_TICKET.md"
if [ -f "$TICKET_FILE" ]; then
  cat "$TICKET_FILE"
else
  echo "[WARNING] Ticket file not found: $TICKET_FILE"
fi

# Update progress + daily log
echo "" >> "$MEMORY_DIR/progress.md"
echo "- [$(date -u +'%Y-%m-%d %H:%M:%S')] Started: $NEXT_TICKET" >> "$MEMORY_DIR/progress.md"
echo "- [$(date -u +'%H:%M:%S')] Picked up ticket: $NEXT_TICKET" >> "$MEMORY_DIR/daily-log.md"

# Update MEMORY.md active ticket
TEMP=$(mktemp -p "${PROJECT_ROOT}")
sed "s/\*\*Active Ticket:\*\*.*/\*\*Active Ticket:\*\* $NEXT_TICKET — in_progress/" "$MEMORY_DIR/MEMORY.md" > "$TEMP"
mv "$TEMP" "$MEMORY_DIR/MEMORY.md"

exit 0
