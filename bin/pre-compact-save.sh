#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# pre-compact-save.sh — PreCompact hook
# Fires before: context compaction
# Purpose: Archive daily log + snapshot current state so nothing is lost
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="${HARNESS_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$HARNESS_DIR/.." && pwd)}"
MEMORY_DIR="$PROJECT_ROOT/memory"
ARCHIVE_DIR="$MEMORY_DIR/archives"
QUEUE="$PROJECT_ROOT/tickets/QUEUE.json"

mkdir -p "$ARCHIVE_DIR"

TIMESTAMP=$(date -u +'%Y%m%d-%H%M%S')

# --- Archive daily log ---
if [ -f "$MEMORY_DIR/daily-log.md" ]; then
  # Only archive if there's actual content (more than the template header)
  LINE_COUNT=$(wc -l < "$MEMORY_DIR/daily-log.md" 2>/dev/null || echo "0")
  if [ "$LINE_COUNT" -gt 5 ]; then
    cp "$MEMORY_DIR/daily-log.md" "$ARCHIVE_DIR/session-$TIMESTAMP.md"

    # Reset daily log
    cat > "$MEMORY_DIR/daily-log.md" << EOF
# Session Log

<!-- Previous session archived to archives/session-$TIMESTAMP.md -->

## $(date -u +'%Y-%m-%d %H:%M:%S') — Session resumed after compaction
EOF
  fi
fi

# --- Update MEMORY.md with current state ---
if [ -f "$QUEUE" ]; then
  CURRENT_TICKET=$(jq -r '.current_ticket // "none"' "$QUEUE" 2>/dev/null || echo "none")
  DONE_COUNT=$(jq '[.queue[] | select(.status=="done")] | length' "$QUEUE" 2>/dev/null || echo "0")
  TOTAL_COUNT=$(jq '.queue | length' "$QUEUE" 2>/dev/null || echo "0")

  # Update the status section in MEMORY.md
  if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
    # Use a temp file for safe in-place edit
    TEMP=$(TMPDIR="${PROJECT_ROOT}" mktemp)
    awk -v ticket="$CURRENT_TICKET" -v done="$DONE_COUNT" -v total="$TOTAL_COUNT" -v ts="$(date -u +'%Y-%m-%d %H:%M:%S UTC')" '
      /^- \*\*Active Ticket:\*\*/ { print "- **Active Ticket:** " ticket; next }
      /^- \*\*Last Updated:\*\*/ { print "- **Last Updated:** " ts; next }
      { print }
    ' "$MEMORY_DIR/MEMORY.md" > "$TEMP"
    mv "$TEMP" "$MEMORY_DIR/MEMORY.md"
  fi
fi

# --- Sync progress.md with QUEUE.json ---
if [ -f "$QUEUE" ] && [ -f "$MEMORY_DIR/progress.md" ]; then
  TEMP=$(TMPDIR="${PROJECT_ROOT}" mktemp)
  cat > "$TEMP" << 'EOF'
# Progress Tracker

EOF

  # Completed
  echo "## Completed" >> "$TEMP"
  jq -r '.queue[] | select(.status=="done") | "- [x] " + .id + " — " + .title' "$QUEUE" 2>/dev/null >> "$TEMP" || echo "[None yet]" >> "$TEMP"
  echo "" >> "$TEMP"

  # In Progress
  echo "## In Progress" >> "$TEMP"
  jq -r '.queue[] | select(.status=="in_progress") | "- [ ] " + .id + " — " + .title' "$QUEUE" 2>/dev/null >> "$TEMP" || echo "[None]" >> "$TEMP"
  echo "" >> "$TEMP"

  # Blocked / Backlog
  echo "## Backlog" >> "$TEMP"
  jq -r '.queue[] | select(.status=="ready" or .status=="backlog") | "- [ ] " + .id + " — " + .title + " (" + .status + ")"' "$QUEUE" 2>/dev/null >> "$TEMP" || echo "[None]" >> "$TEMP"

  mv "$TEMP" "$MEMORY_DIR/progress.md"
fi

echo "[HARNESS] State archived before compaction (archives/session-$TIMESTAMP.md)"
exit 0
