#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# verify-all.sh — Main acceptance criteria dispatcher
# Usage: harness/acceptance/verify-all.sh <ticket-id> [--verbose]
#
# Reads the ticket file, extracts AC types, runs the matching verifier.
# Exit 0 = all pass, Exit 2 = at least one failure
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TICKETS_DIR="$PROJECT_ROOT/tickets"
ACCEPTANCE_DIR="$PROJECT_ROOT/harness/acceptance"

TICKET_ID="${1:-}"
VERBOSE="${2:-}"

if [ -z "$TICKET_ID" ]; then
  echo "[ERROR] No ticket ID provided."
  echo "Usage: harness/acceptance/verify-all.sh <ticket-id>"
  exit 1
fi

# Find ticket file (check both active and completed)
TICKET_FILE="$TICKETS_DIR/$TICKET_ID.md"
if [ ! -f "$TICKET_FILE" ]; then
  TICKET_FILE="$TICKETS_DIR/completed/$TICKET_ID.md"
fi
if [ ! -f "$TICKET_FILE" ]; then
  echo "[ERROR] Ticket file not found: $TICKET_ID"
  exit 1
fi

echo "============================================"
echo "  Verifying AC: $TICKET_ID"
echo "============================================"
echo ""

# --- Extract unique AC types from ticket ---
# AC lines look like: - [ ] `build`: description
# or:                  - [x] `api`: description
AC_TYPES=$(grep -oP '`\K[a-z_]+(?=`)' "$TICKET_FILE" | sort -u 2>/dev/null || echo "")

if [ -z "$AC_TYPES" ]; then
  echo "[WARN] No acceptance criteria found in ticket."
  echo "[PASS] (vacuously true — no criteria to check)"
  exit 0
fi

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
FAILURES=""

for AC_TYPE in $AC_TYPES; do
  TOTAL=$((TOTAL + 1))
  VERIFIER="$ACCEPTANCE_DIR/verify-$AC_TYPE.sh"

  if [ -f "$VERIFIER" ]; then
    echo "[CHECK] $AC_TYPE..."

    # Run verifier, capture output
    OUTPUT=$(bash "$VERIFIER" "$TICKET_ID" "$TICKET_FILE" 2>&1) || {
      FAILED=$((FAILED + 1))
      FAILURES="$FAILURES\n  - $AC_TYPE: $OUTPUT"
      echo "[FAIL] $AC_TYPE"
      if [ "$VERBOSE" = "--verbose" ]; then
        echo "$OUTPUT" | head -20 | sed 's/^/    /'
      fi
      continue
    }

    PASSED=$((PASSED + 1))
    echo "[PASS] $AC_TYPE"
    if [ "$VERBOSE" = "--verbose" ]; then
      echo "$OUTPUT" | head -10 | sed 's/^/    /'
    fi
  else
    SKIPPED=$((SKIPPED + 1))
    echo "[SKIP] $AC_TYPE (no verifier: verify-$AC_TYPE.sh)"
  fi
done

echo ""
echo "============================================"
echo "  Results: $PASSED passed, $FAILED failed, $SKIPPED skipped (of $TOTAL)"
echo "============================================"

if [ "$FAILED" -gt 0 ]; then
  echo ""
  echo "Failures:"
  echo -e "$FAILURES"
  echo ""
  echo "Fix these issues and run again."
  exit 2
fi

if [ "$SKIPPED" -gt 0 ]; then
  echo ""
  echo "[WARN] $SKIPPED AC types had no verifier script."
  echo "Create harness/acceptance/verify-<type>.sh for full coverage."
fi

echo ""
echo "[SUCCESS] All verifiable acceptance criteria passed."
exit 0
