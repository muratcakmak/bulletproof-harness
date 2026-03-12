#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# update-memory.sh — Append notes to the right memory file
# Usage: harness/bin/update-memory.sh <category> "note text"
#
# Categories:
#   architecture  → memory/architecture.md
#   conventions   → memory/conventions.md
#   progress      → memory/progress.md
#   bugs          → memory/bugs.md
#   log           → memory/daily-log.md
#   decision      → memory/MEMORY.md (Key Decisions section)
#   blocker       → memory/MEMORY.md (Current Blockers section)
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MEMORY_DIR="$PROJECT_ROOT/memory"

CATEGORY="${1:-}"
NOTE="${2:-}"

if [ -z "$CATEGORY" ] || [ -z "$NOTE" ]; then
  echo "Usage: harness/bin/update-memory.sh <category> 'note text'"
  echo ""
  echo "Categories: architecture, conventions, progress, bugs, log, decision, blocker"
  echo ""
  echo "Examples:"
  echo "  harness/bin/update-memory.sh bugs 'WebSocket disconnects after 60s idle'"
  echo "  harness/bin/update-memory.sh decision 'Using JWT over sessions for stateless auth'"
  echo "  harness/bin/update-memory.sh log 'Finished API endpoint, all tests pass'"
  exit 1
fi

TIMESTAMP=$(date -u +'%Y-%m-%d %H:%M:%S')

case "$CATEGORY" in
  architecture|arch)
    echo "" >> "$MEMORY_DIR/architecture.md"
    echo "### [$TIMESTAMP] $NOTE" >> "$MEMORY_DIR/architecture.md"
    echo "[OK] Updated memory/architecture.md"
    ;;
  conventions|conv)
    echo "" >> "$MEMORY_DIR/conventions.md"
    echo "### [$TIMESTAMP] $NOTE" >> "$MEMORY_DIR/conventions.md"
    echo "[OK] Updated memory/conventions.md"
    ;;
  progress)
    echo "" >> "$MEMORY_DIR/progress.md"
    echo "- [$TIMESTAMP] $NOTE" >> "$MEMORY_DIR/progress.md"
    echo "[OK] Updated memory/progress.md"
    ;;
  bugs|bug)
    echo "" >> "$MEMORY_DIR/bugs.md"
    echo "## $NOTE [ACTIVE]" >> "$MEMORY_DIR/bugs.md"
    echo "- **Reported:** $TIMESTAMP" >> "$MEMORY_DIR/bugs.md"
    echo "- **Symptom:** [describe]" >> "$MEMORY_DIR/bugs.md"
    echo "- **Root Cause:** [investigate]" >> "$MEMORY_DIR/bugs.md"
    echo "- **Workaround:** [if any]" >> "$MEMORY_DIR/bugs.md"
    echo "" >> "$MEMORY_DIR/bugs.md"
    echo "[OK] Added bug to memory/bugs.md (fill in details)"
    ;;
  log)
    echo "- [$TIMESTAMP] $NOTE" >> "$MEMORY_DIR/daily-log.md"
    echo "[OK] Updated memory/daily-log.md"
    ;;
  decision)
    # Append to Key Decisions section in MEMORY.md
    TEMP=$(mktemp -p "${PROJECT_ROOT}")
    awk -v note="$NOTE" -v ts="$TIMESTAMP" '
      /^\[Will be populated as decisions/ { print "- [" ts "] " note; next }
      /^## Key Decisions/ { print; getline; print; print "- [" ts "] " note; next }
      { print }
    ' "$MEMORY_DIR/MEMORY.md" > "$TEMP"

    # If awk didn't find the section, just append
    if diff -q "$TEMP" "$MEMORY_DIR/MEMORY.md" &>/dev/null; then
      echo "" >> "$MEMORY_DIR/MEMORY.md"
      echo "- [$TIMESTAMP] Decision: $NOTE" >> "$MEMORY_DIR/MEMORY.md"
    else
      mv "$TEMP" "$MEMORY_DIR/MEMORY.md"
    fi
    rm -f "$TEMP"
    echo "[OK] Added decision to memory/MEMORY.md"
    ;;
  blocker)
    TEMP=$(mktemp -p "${PROJECT_ROOT}")
    awk -v note="$NOTE" -v ts="$TIMESTAMP" '
      /^\[None yet\]/ && found_blockers { print "- [" ts "] " note; next }
      /^## Current Blockers/ { found_blockers=1 }
      /^## / && !/^## Current Blockers/ { found_blockers=0 }
      { print }
    ' "$MEMORY_DIR/MEMORY.md" > "$TEMP"
    mv "$TEMP" "$MEMORY_DIR/MEMORY.md"
    echo "[OK] Added blocker to memory/MEMORY.md"
    ;;
  *)
    echo "[ERROR] Unknown category: $CATEGORY"
    echo "Valid categories: architecture, conventions, progress, bugs, log, decision, blocker"
    exit 1
    ;;
esac

exit 0
