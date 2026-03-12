#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# init-harness.sh — One-time setup for the Bulletproof Harness
# Run this once in any new project to scaffold the full harness structure.
#
# Usage:
#   bash harness/bin/init-harness.sh [project-name]           # in-project
#   bash init-harness.sh --target /path/to/project [name]     # standalone install
# ============================================================================

HARNESS_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse --target flag for standalone install
PROJECT_ROOT=""
PROJECT_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      PROJECT_ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    *)
      PROJECT_NAME="$1"
      shift
      ;;
  esac
done

# Default: assume we're inside harness/bin/ within the project
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(cd "$HARNESS_SOURCE/../.." && pwd)"
fi
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_ROOT")}"

# If running from standalone repo, copy harness scripts into target
STANDALONE_ROOT="$(cd "$HARNESS_SOURCE/.." && pwd)"
if [ "$STANDALONE_ROOT" != "$PROJECT_ROOT/harness" ]; then
  echo "[INSTALL] Copying harness into $PROJECT_ROOT/harness/ ..."
  mkdir -p "$PROJECT_ROOT/harness"
  cp -r "$STANDALONE_ROOT/bin" "$PROJECT_ROOT/harness/"
  cp -r "$STANDALONE_ROOT/acceptance" "$PROJECT_ROOT/harness/"
  cp -r "$STANDALONE_ROOT/skills" "$PROJECT_ROOT/harness/"
  if [ -d "$STANDALONE_ROOT/cli/src" ]; then
    cp -r "$STANDALONE_ROOT/cli" "$PROJECT_ROOT/harness/"
  fi
  echo "[OK] Harness scripts installed"
fi

echo "================================================"
echo "  Bulletproof Harness — Initializing"
echo "  Project: $PROJECT_NAME"
echo "  Root:    $PROJECT_ROOT"
echo "================================================"
echo ""

# --- Create directories ---
mkdir -p "$PROJECT_ROOT"/{memory/archives,tickets/completed,.claude,harness/{bin,acceptance}}
echo "[OK] Directory structure created"

# --- CLAUDE.md (only if not exists) ---
if [ ! -f "$PROJECT_ROOT/CLAUDE.md" ]; then
  cat > "$PROJECT_ROOT/CLAUDE.md" << 'CLAUDEEOF'
# [PROJECT_NAME] — Bulletproof Harness

## You Are
A senior full-stack engineer working in focused ticket cycles with persistent memory.
You do NOT ask questions — you make reasonable assumptions and keep building.
You commit after each completed ticket. If something fails after 3 retries, leave a
`// TODO: [issue]` comment, file a bug in memory/bugs.md, and move on.

## The Project
[EDIT THIS: 2-3 sentence project description]

**Tech Stack:** [EDIT THIS: e.g., TypeScript, React, Node.js, PostgreSQL]
**Architecture:** [EDIT THIS: e.g., Monorepo with shared types]
**Deadline:** [EDIT THIS: if applicable]

## Harness System
This project uses the Bulletproof Harness for autonomous development:

- **Memory:** `memory/MEMORY.md` (index) — search with `harness/bin/search-memory.sh "query"`
- **Tickets:** `tickets/QUEUE.json` (state machine) — next with `harness/bin/next-ticket.sh`
- **Conventions:** `memory/conventions.md` (code style + patterns)
- **Bugs:** `memory/bugs.md` (known issues + workarounds)
- **Progress:** `memory/progress.md` (done / in-progress / blocked)

## Critical Rules
1. **Never mark a ticket done without passing acceptance verification**
   Run: `harness/bin/mark-done.sh [ticket-id]` (runs AC checks automatically)
2. **Search memory before writing code** — reuse patterns, don't reinvent
3. **Commit after every completed ticket** with format: `ticket-NNNN: brief description`
4. **Update memory with findings:** `harness/bin/update-memory.sh "category" "note"`
5. **If stuck 3+ retries:** file bug → `harness/bin/update-memory.sh bugs "description"` → move on
6. **Follow conventions** in `memory/conventions.md` — never invent new patterns without updating it

## Workflow
```
1. harness/bin/next-ticket.sh          # Get assigned ticket
2. Read ticket → plan → code → test
3. harness/bin/mark-done.sh NNNN       # Verify AC + archive + advance
4. git add -A && git commit            # Commit with ticket ID
5. Repeat
```

## Acceptance Verification
Before finishing ANY ticket, the harness verifies:
- `build`: TypeScript compiles, lint passes, tests pass
- `api`: Endpoints return expected status codes + JSON
- `unit_test`: Specific test files pass with coverage
- `visual`: UI renders correctly (Chrome MCP screenshot)
- `functional`: Click-through flows work (Chrome MCP interaction)

The Stop hook enforces this — you cannot declare done without passing.
CLAUDEEOF
  # Replace PROJECT_NAME placeholder
  sed -i "s/\[PROJECT_NAME\]/$PROJECT_NAME/g" "$PROJECT_ROOT/CLAUDE.md"
  echo "[OK] Created CLAUDE.md (edit project details!)"
else
  echo "[SKIP] CLAUDE.md already exists"
fi

# --- Memory files ---
if [ ! -f "$PROJECT_ROOT/memory/MEMORY.md" ]; then
  cat > "$PROJECT_ROOT/memory/MEMORY.md" << 'EOF'
# Memory Index

## Current Status
- **Active Ticket:** None — run `harness/bin/next-ticket.sh` to start
- **Last Updated:** [auto-updated by hooks]
- **Session Count:** 0

## Quick Links
- Architecture decisions → `memory/architecture.md`
- Code conventions → `memory/conventions.md`
- Progress tracker → `memory/progress.md`
- Known bugs → `memory/bugs.md`
- Session log → `memory/daily-log.md`

## Key Decisions
[Will be populated as decisions are made]

## Current Blockers
[None yet]

## Recent Changes
[Will be populated as work progresses]
EOF
  echo "[OK] Created memory/MEMORY.md"
fi

if [ ! -f "$PROJECT_ROOT/memory/architecture.md" ]; then
  cat > "$PROJECT_ROOT/memory/architecture.md" << 'EOF'
# System Architecture

## Overview
[EDIT: High-level description of the system]

## Data Flow
[EDIT: How data moves through the system]

## Component Responsibilities
[EDIT: What each major component does]

## Technology Rationale
[EDIT: Why each technology was chosen]

## Key Patterns
[Will be populated as patterns emerge]

## Deployment
[EDIT: How the system is deployed]
EOF
  echo "[OK] Created memory/architecture.md"
fi

if [ ! -f "$PROJECT_ROOT/memory/conventions.md" ]; then
  cat > "$PROJECT_ROOT/memory/conventions.md" << 'EOF'
# Coding Conventions

## File Structure
[EDIT: Your project's directory layout]

## Naming
- **Files:** kebab-case (e.g., user-service.ts)
- **Classes/Components:** PascalCase (e.g., UserService)
- **Functions/Variables:** camelCase (e.g., getUserById)
- **Constants:** UPPER_SNAKE_CASE (e.g., MAX_RETRIES)
- **Database tables:** snake_case plural (e.g., user_sessions)

## Imports
- Group: node builtins → third-party → local modules → types
- Use absolute paths where configured
- No circular dependencies

## Error Handling
[EDIT: Your error handling patterns]

## Testing
[EDIT: Test file locations, naming, patterns]

## Git
- Commit format: `ticket-NNNN: brief description`
- One logical change per commit
- Always run type-check before committing
EOF
  echo "[OK] Created memory/conventions.md"
fi

if [ ! -f "$PROJECT_ROOT/memory/progress.md" ]; then
  cat > "$PROJECT_ROOT/memory/progress.md" << 'EOF'
# Progress Tracker

## Completed
[None yet]

## In Progress
[None yet]

## Blocked
[None yet]

## Backlog
[Run `harness/bin/generate-tickets.sh` to populate from plan]
EOF
  echo "[OK] Created memory/progress.md"
fi

if [ ! -f "$PROJECT_ROOT/memory/bugs.md" ]; then
  cat > "$PROJECT_ROOT/memory/bugs.md" << 'EOF'
# Known Issues & Workarounds

[No bugs yet — will be populated during development]

<!-- Format:
## [Short Title] [ACTIVE|RESOLVED]
- **Symptom:** What you see
- **Root Cause:** Why it happens
- **Workaround:** Temporary fix
- **Fix:** Permanent solution (link to ticket if exists)
- **Resolved in:** ticket-NNNN (if resolved)
-->
EOF
  echo "[OK] Created memory/bugs.md"
fi

if [ ! -f "$PROJECT_ROOT/memory/daily-log.md" ]; then
  cat > "$PROJECT_ROOT/memory/daily-log.md" << 'EOF'
# Session Log

[Will be populated by SessionStart hook and during work]

<!-- Format:
## YYYY-MM-DD HH:MM — [Action]
- What was done
- What was learned
- What's next
-->
EOF
  echo "[OK] Created memory/daily-log.md"
fi

# --- Ticket system ---
if [ ! -f "$PROJECT_ROOT/tickets/QUEUE.json" ]; then
  cat > "$PROJECT_ROOT/tickets/QUEUE.json" << 'EOF'
{
  "current_ticket": null,
  "queue": []
}
EOF
  echo "[OK] Created tickets/QUEUE.json"
fi

if [ ! -f "$PROJECT_ROOT/tickets/_plan.md" ]; then
  cat > "$PROJECT_ROOT/tickets/_plan.md" << 'EOF'
# Build Plan

<!--
This file is parsed by harness/bin/generate-tickets.sh to create individual tickets.
Use the format below for each task. Separate tasks with --- on its own line.

Fields:
  ### Task N: Title        (required — ticket number and title)
  Summary: text            (required — what to build)
  Files: file1, file2      (optional — files to create/modify)
  AC: type1, type2         (required — acceptance criteria types: build, api, unit_test, visual, functional)
  Depends: N, M            (optional — ticket numbers this depends on, or "none")
  Size: Small|Medium|Large (optional — estimated effort)
-->

### Task 1: Project Setup
Summary: Initialize project structure, package.json, TypeScript config, and development tooling
Files: package.json, tsconfig.json, .gitignore, .env.example
AC: build
Depends: none
Size: Small
---
EOF
  echo "[OK] Created tickets/_plan.md (edit with your build plan!)"
fi

# --- .claude/settings.json ---
if [ ! -f "$PROJECT_ROOT/.claude/settings.json" ]; then
  cat > "$PROJECT_ROOT/.claude/settings.json" << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash harness/bin/session-start.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash harness/bin/post-edit-typecheck.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash harness/bin/pre-compact-save.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash harness/bin/stop-verify.sh"
          }
        ]
      }
    ]
  }
}
EOF
  echo "[OK] Created .claude/settings.json (hooks configured)"
fi

# --- Make all scripts executable ---
chmod +x "$PROJECT_ROOT"/harness/bin/*.sh 2>/dev/null || true
chmod +x "$PROJECT_ROOT"/harness/acceptance/*.sh 2>/dev/null || true

echo ""
echo "================================================"
echo "  Harness initialized successfully!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Edit CLAUDE.md with your project details"
echo "  2. Edit memory/conventions.md with your code style"
echo "  3. Edit memory/architecture.md with your system design"
echo "  4. Write your build plan in tickets/_plan.md"
echo "  5. Run: harness/bin/generate-tickets.sh"
echo "  6. Run: harness/bin/next-ticket.sh"
echo ""
