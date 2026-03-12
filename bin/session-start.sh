#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# session-start.sh — SessionStart hook
# Fires on: startup, resume, compact
# Purpose: Inject memory + current ticket into Claude's context
# Output: stdout → added to Claude's context window
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MEMORY_DIR="$PROJECT_ROOT/memory"
TICKETS_DIR="$PROJECT_ROOT/tickets"
QUEUE="$TICKETS_DIR/QUEUE.json"

# Read the event source from stdin (startup|resume|compact)
INPUT=$(cat 2>/dev/null || echo '{}')
SOURCE=$(echo "$INPUT" | jq -r '.source // "unknown"' 2>/dev/null || echo "unknown")

echo "============================================"
echo "  HARNESS — Session Start ($SOURCE)"
echo "  $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "============================================"
echo ""

# --- Layer 1: Memory Index (always) ---
if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
  echo "--- MEMORY INDEX ---"
  cat "$MEMORY_DIR/MEMORY.md"
  echo ""
fi

# --- Layer 2: Current Ticket (if assigned) ---
if [ -f "$QUEUE" ]; then
  CURRENT_TICKET=$(jq -r '.current_ticket // empty' "$QUEUE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_TICKET" ]; then
    TICKET_FILE="$TICKETS_DIR/$CURRENT_TICKET.md"
    if [ -f "$TICKET_FILE" ]; then
      echo "--- CURRENT TICKET: $CURRENT_TICKET ---"
      cat "$TICKET_FILE"
      echo ""
    else
      echo "--- WARNING: Ticket file not found: $TICKET_FILE ---"
    fi
  else
    echo "--- NO ACTIVE TICKET ---"
    echo "Run: harness/bin/next-ticket.sh to pick up the next ticket"
    echo ""
  fi
fi

# --- Layer 3: Recent progress (compact summary) ---
if [ -f "$MEMORY_DIR/progress.md" ]; then
  echo "--- PROGRESS SUMMARY ---"
  # Show just the status sections, not full file
  head -30 "$MEMORY_DIR/progress.md"
  echo ""
fi

# --- Layer 4: Active bugs (if any) ---
if [ -f "$MEMORY_DIR/bugs.md" ]; then
  ACTIVE_BUGS=$(grep -c "\[ACTIVE\]" "$MEMORY_DIR/bugs.md" 2>/dev/null || echo "0")
  if [ "$ACTIVE_BUGS" -gt 0 ]; then
    echo "--- ACTIVE BUGS ($ACTIVE_BUGS) ---"
    grep -A 4 "\[ACTIVE\]" "$MEMORY_DIR/bugs.md" 2>/dev/null || true
    echo ""
  fi
fi

# --- On compact: remind about what was in progress ---
if [ "$SOURCE" = "compact" ]; then
  echo "--- CONTEXT RESTORED AFTER COMPACTION ---"
  echo "Your previous context was compacted. Key state has been reloaded above."
  echo "Check memory/daily-log.md for recent session notes."
  echo "Run: harness/bin/search-memory.sh 'keyword' to find specific context."
  echo ""
fi

# --- Update daily log ---
{
  echo ""
  echo "## $(date -u +'%Y-%m-%d %H:%M:%S') — Session $SOURCE"
  echo "- Harness loaded memory + ticket context"
} >> "$MEMORY_DIR/daily-log.md" 2>/dev/null || true

# Exit 0 = all stdout injected into Claude's context
exit 0
