#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# generate-tickets.sh — Parse _plan.md and generate individual ticket files
#
# Reads tickets/_plan.md and creates:
#   - Individual ticket markdown files (tickets/NNNN-kebab-title.md)
#   - Updated QUEUE.json with all tickets and dependencies
#
# Plan format (separate tasks with --- on its own line):
#   ### Task N: Title
#   Summary: What to build
#   Files: file1, file2
#   AC: build, api, unit_test, visual, functional
#   Depends: N, M (or "none")
#   Size: Small|Medium|Large
# ============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TICKETS_DIR="$PROJECT_ROOT/tickets"
PLAN_FILE="$TICKETS_DIR/_plan.md"
QUEUE_FILE="$TICKETS_DIR/QUEUE.json"

if [ ! -f "$PLAN_FILE" ]; then
  echo "[ERROR] Plan file not found: $PLAN_FILE"
  echo "Create your build plan in tickets/_plan.md first."
  exit 1
fi

echo "============================================"
echo "  Generating tickets from _plan.md"
echo "============================================"
echo ""

# --- Parse plan file into ticket blocks ---

# Initialize QUEUE.json
echo '{"current_ticket": null, "queue": []}' > "$QUEUE_FILE"

TICKET_COUNT=0
CURRENT_NUM=""
CURRENT_TITLE=""
CURRENT_SUMMARY=""
CURRENT_FILES=""
CURRENT_AC=""
CURRENT_DEPENDS=""
CURRENT_SIZE=""

flush_ticket() {
  if [ -z "$CURRENT_NUM" ]; then return; fi

  # Generate kebab-case ID
  KEBAB_TITLE=$(echo "$CURRENT_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
  TICKET_ID=$(printf "%04d" "$CURRENT_NUM")-$KEBAB_TITLE

  # Parse dependencies into JSON array
  DEPENDS_JSON="[]"
  if [ -n "$CURRENT_DEPENDS" ] && [ "$CURRENT_DEPENDS" != "none" ]; then
    DEPENDS_JSON="["
    FIRST=true
    for DEP_NUM in $(echo "$CURRENT_DEPENDS" | tr ',' ' '); do
      DEP_NUM=$(echo "$DEP_NUM" | tr -d ' ')
      if [ -n "$DEP_NUM" ]; then
        # We'll resolve the full ID later; for now store the number
        if [ "$FIRST" = true ]; then
          FIRST=false
        else
          DEPENDS_JSON="$DEPENDS_JSON,"
        fi
        DEPENDS_JSON="$DEPENDS_JSON\"$DEP_NUM\""
      fi
    done
    DEPENDS_JSON="$DEPENDS_JSON]"
  fi

  # Determine initial status
  if [ "$DEPENDS_JSON" = "[]" ]; then
    STATUS="ready"
  else
    STATUS="backlog"
  fi

  # Generate AC section from types
  AC_SECTION=""
  for AC_TYPE in $(echo "$CURRENT_AC" | tr ',' ' '); do
    AC_TYPE=$(echo "$AC_TYPE" | tr -d ' ')
    case "$AC_TYPE" in
      build)
        AC_SECTION="$AC_SECTION- [ ] \`build\`: Project compiles with no errors\n- [ ] \`build\`: Linter passes\n"
        ;;
      api)
        AC_SECTION="$AC_SECTION- [ ] \`api\`: API endpoints return expected status codes\n- [ ] \`api\`: Response JSON matches expected schema\n"
        ;;
      unit_test)
        AC_SECTION="$AC_SECTION- [ ] \`unit_test\`: All relevant test files pass\n- [ ] \`unit_test\`: Adequate test coverage\n"
        ;;
      visual)
        AC_SECTION="$AC_SECTION- [ ] \`visual\`: UI renders correctly in browser\n- [ ] \`visual\`: Layout matches design specification\n"
        ;;
      functional)
        AC_SECTION="$AC_SECTION- [ ] \`functional\`: User flow works end-to-end in browser\n- [ ] \`functional\`: Error states handled gracefully\n"
        ;;
      *)
        AC_SECTION="$AC_SECTION- [ ] \`$AC_TYPE\`: [EDIT: describe criteria]\n"
        ;;
    esac
  done

  # Generate files section
  FILES_SECTION=""
  if [ -n "$CURRENT_FILES" ]; then
    for FILE in $(echo "$CURRENT_FILES" | tr ',' '\n'); do
      FILE=$(echo "$FILE" | tr -d ' ' | sed 's/^[[:space:]]*//')
      if [ -n "$FILE" ]; then
        FILES_SECTION="$FILES_SECTION- $FILE\n"
      fi
    done
  fi

  # Write ticket file
  TICKET_FILE="$TICKETS_DIR/$TICKET_ID.md"
  cat > "$TICKET_FILE" << TICKETEOF
# Ticket $TICKET_ID: $CURRENT_TITLE

**Status:** $STATUS
**Dependencies:** $([ "$CURRENT_DEPENDS" = "none" ] || [ -z "$CURRENT_DEPENDS" ] && echo "None" || echo "$CURRENT_DEPENDS")
**Size:** ${CURRENT_SIZE:-Medium}

## Summary
$CURRENT_SUMMARY

## Acceptance Criteria
$(echo -e "$AC_SECTION")
## Files to Touch
$(echo -e "${FILES_SECTION:-[EDIT: list files to create/modify]}")

## Implementation Notes
[Add notes during implementation]

## Session Notes
[Auto-filled during work]
TICKETEOF

  # Add to QUEUE.json
  TEMP=$(mktemp -p "${PROJECT_ROOT}")
  jq --arg id "$TICKET_ID" \
     --arg title "$CURRENT_TITLE" \
     --arg status "$STATUS" \
     --argjson deps "$DEPENDS_JSON" \
    '.queue += [{"id": $id, "title": $title, "status": $status, "depends_on": $deps}]' \
    "$QUEUE_FILE" > "$TEMP" && mv "$TEMP" "$QUEUE_FILE"

  TICKET_COUNT=$((TICKET_COUNT + 1))
  echo "  [+] $TICKET_ID ($STATUS)"

  # Reset
  CURRENT_NUM=""
  CURRENT_TITLE=""
  CURRENT_SUMMARY=""
  CURRENT_FILES=""
  CURRENT_AC=""
  CURRENT_DEPENDS=""
  CURRENT_SIZE=""
}

# --- Parse the plan file line by line ---
while IFS= read -r line; do
  # Skip HTML comments
  if [[ "$line" =~ ^\<\!-- ]] || [[ "$line" =~ ^--\> ]]; then continue; fi

  # Task header: ### Task N: Title
  if [[ "$line" =~ ^###[[:space:]]+Task[[:space:]]+([0-9]+):[[:space:]]*(.*) ]]; then
    flush_ticket
    CURRENT_NUM="${BASH_REMATCH[1]}"
    CURRENT_TITLE="${BASH_REMATCH[2]}"
    continue
  fi

  # Separator between tasks
  if [[ "$line" =~ ^---[[:space:]]*$ ]]; then
    flush_ticket
    continue
  fi

  # Field parsers
  if [[ "$line" =~ ^Summary:[[:space:]]*(.*) ]]; then
    CURRENT_SUMMARY="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^Files:[[:space:]]*(.*) ]]; then
    CURRENT_FILES="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^AC:[[:space:]]*(.*) ]]; then
    CURRENT_AC="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^Depends:[[:space:]]*(.*) ]]; then
    CURRENT_DEPENDS="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^Size:[[:space:]]*(.*) ]]; then
    CURRENT_SIZE="${BASH_REMATCH[1]}"
  fi
done < "$PLAN_FILE"

# Flush last ticket
flush_ticket

echo ""
echo "============================================"
echo "  Generated $TICKET_COUNT tickets"
echo "============================================"
echo ""

# Show queue summary
echo "Queue:"
jq -r '.queue[] | "  " + .id + " [" + .status + "]"' "$QUEUE_FILE"

echo ""
echo "Next: run harness/bin/next-ticket.sh to start working"

exit 0
