#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# search-memory.sh — Search across all memory files
# Usage: harness/bin/search-memory.sh "pattern" [--context N]
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MEMORY_DIR="$PROJECT_ROOT/memory"

PATTERN="${1:-}"
CONTEXT="${2:-3}"

if [ -z "$PATTERN" ]; then
  echo "Usage: harness/bin/search-memory.sh <pattern> [--context N]"
  echo ""
  echo "Searches all memory/*.md files for the given pattern."
  echo "Examples:"
  echo "  harness/bin/search-memory.sh 'database'"
  echo "  harness/bin/search-memory.sh 'auth' --context 5"
  exit 1
fi

# Handle --context flag
if [ "${2:-}" = "--context" ]; then
  CONTEXT="${3:-3}"
fi

echo "Searching memory for: '$PATTERN'"
echo "============================================"

# Search memory files (exclude archives for speed, search separately if needed)
RESULTS=$(grep -r -i -n --include="*.md" -C "$CONTEXT" "$PATTERN" "$MEMORY_DIR" \
  --exclude-dir=archives 2>/dev/null || true)

if [ -n "$RESULTS" ]; then
  echo "$RESULTS"
  echo ""
  MATCH_COUNT=$(echo "$RESULTS" | grep -c "^$MEMORY_DIR" 2>/dev/null || echo "?")
  echo "--- $MATCH_COUNT matches found ---"
else
  echo "[NO RESULTS in active memory]"
  echo ""

  # Try archives as fallback
  ARCHIVE_RESULTS=$(grep -r -i -n --include="*.md" -C 1 "$PATTERN" "$MEMORY_DIR/archives" 2>/dev/null || true)
  if [ -n "$ARCHIVE_RESULTS" ]; then
    echo "Found in archives:"
    echo "$ARCHIVE_RESULTS" | head -20
  else
    echo "No matches found anywhere. Try a broader search term."
  fi
fi

# Also search tickets for completeness
TICKET_RESULTS=$(grep -r -i -n --include="*.md" "$PATTERN" "$PROJECT_ROOT/tickets" 2>/dev/null || true)
if [ -n "$TICKET_RESULTS" ]; then
  echo ""
  echo "--- Also found in tickets: ---"
  echo "$TICKET_RESULTS" | head -10
fi

exit 0
