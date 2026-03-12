# Bulletproof Harness

**Autonomous ticket-driven development orchestrator for Claude Code.**

Bulletproof Harness is a general-purpose framework that turns any web app project into a structured, autonomous build pipeline. It gives Claude Code persistent memory across sessions, a ticket queue with dependency resolution, enforced acceptance criteria, and Claude Code hooks that prevent premature completion. It works for any tech stack — TypeScript, Python, Go, Rust, or anything with a build step.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture](#architecture)
3. [Installation](#installation)
4. [CLI Commands](#cli-commands)
5. [Memory System](#memory-system)
6. [Ticket System](#ticket-system)
7. [Acceptance Criteria](#acceptance-criteria)
8. [Claude Code Hooks](#claude-code-hooks)
9. [Skills](#skills)
10. [Loop Mode (Autonomous)](#loop-mode-autonomous)
11. [Plan Wizard](#plan-wizard)
12. [Directory Structure](#directory-structure)
13. [Configuration](#configuration)
14. [Extending the Harness](#extending-the-harness)

---

## Quick Start

```bash
# 1. Initialize the harness in your project
cd your-project
harness init "My Project"

# 2. Edit your project details
$EDITOR CLAUDE.md
$EDITOR memory/conventions.md

# 3. Generate tickets from a PRD or interactively
harness plan --prd requirements.md
# OR
harness plan  # interactive wizard

# 4. Start working
harness next          # pick up first ticket
# ... do the work ...
harness done 0001     # verify AC + archive + advance

# 5. Or let Claude Code do it all
harness loop          # autonomous mode
```

---

## Architecture

The harness is built on three pillars that work together through Claude Code hooks:

```
┌─────────────────────────────────────────────────┐
│                  CLAUDE.md                       │
│           (project rules, <200 lines)            │
├─────────────┬──────────────┬────────────────────┤
│   MEMORY    │   TICKETS    │   ACCEPTANCE        │
│  4-layer    │  markdown    │   build / api /     │
│  persistent │  queue +     │   unit_test /       │
│  searchable │  auto-chain  │   visual /          │
│             │              │   functional        │
├─────────────┴──────────────┴────────────────────┤
│              CLAUDE CODE HOOKS                   │
│  SessionStart → PostToolUse → Stop → PreCompact  │
└─────────────────────────────────────────────────┘
```

**Memory** persists knowledge across sessions and context compactions. **Tickets** provide a dependency-aware queue that chains tasks automatically. **Acceptance criteria** enforce real verification (type-check, curl, screenshot, click-through) before any ticket can be marked done. **Hooks** wire it all together so Claude Code loads context on startup, type-checks after edits, verifies before stopping, and archives before compaction.

---

## Installation

### Prerequisites

- Node.js 18+
- Claude Code CLI (`npm i -g @anthropic-ai/claude-code`)
- jq (for shell scripts)
- bash 4+

### Install the CLI

```bash
cd harness/cli
npm install
npm run build
npm link     # makes 'harness' available globally
```

Or run directly without linking:

```bash
node harness/cli/dist/index.js <command>
```

### Initialize a project

```bash
harness init "My Project"
```

This creates the full directory tree: `memory/`, `tickets/`, `harness/bin/`, `harness/acceptance/`, `.claude/settings.json`, and template files for CLAUDE.md and all memory files. If CLAUDE.md already exists, it won't overwrite it (use `--force` to reinitialize).

---

## CLI Commands

### `harness init [name]`

Initialize the harness in the current directory.

| Option    | Description                         |
|-----------|-------------------------------------|
| `--force` | Overwrite existing harness files    |

```bash
harness init "FormCoach"
harness init --force "FormCoach"
```

After init, edit `CLAUDE.md` with your project description, tech stack, and architecture. Edit `memory/conventions.md` with your code style and patterns.

---

### `harness plan`

Generate tickets from a build plan. Three modes:

**Interactive wizard** (default) — asks about your project and generates a plan using Claude Code:

```bash
harness plan
```

The wizard asks: what you're building, tech stack, project size (5-8 / 8-15 / 15-25 tickets), key features, deadline, and whether you have an API / frontend / database. It sends the answers to Claude Code to generate a structured plan, then parses it into ticket files.

**From a PRD file** — sends a product requirements document to Claude Code:

```bash
harness plan --prd requirements.md
```

**From an existing plan file** — parses `tickets/_plan.md` directly:

```bash
harness plan --from-file
```

| Option           | Description                                     |
|------------------|-------------------------------------------------|
| `--prd <file>`   | Generate plan from a PRD document               |
| `--from-file`    | Skip wizard, generate directly from _plan.md    |

If Claude Code is not installed, the wizard generates a template plan that you can edit manually.

---

### `harness next`

Pick up the next ready ticket. Sets it to `in_progress` in QUEUE.json and prints the ticket content. Automatically promotes backlog tickets whose dependencies are satisfied.

```bash
harness next
```

---

### `harness done [ticket-id]`

Verify acceptance criteria, archive the ticket, and advance the queue.

```bash
harness done 0002-create-api
harness done           # uses current ticket
```

This runs all AC checks first. If any fail, the ticket stays in progress and you get a report of what's not passing. If all pass, the ticket moves to `completed/`, QUEUE.json updates, and the next ready ticket is promoted.

---

### `harness status`

Show the current queue with a visual progress bar, color-coded ticket statuses, and recent activity.

```bash
harness status
harness status --json      # machine-readable output
harness status --memory    # include memory index summary
```

| Option     | Description                     |
|------------|---------------------------------|
| `--json`   | Output as JSON                  |
| `--memory` | Include memory summary          |

Example output:

```
  ██████████████████░░░░░░░░░░░░ 60% (3/5)

  ✓ done       0001-project-setup
  ✓ done       0002-database-schema
  ✓ done       0003-api-foundation
  ▶ in_progress  0004-auth-system ← depends: 2, 3
  ○ backlog    0005-frontend ← depends: 1

  Current: 0004-auth-system
  1 active · 0 ready · 1 backlog
```

---

### `harness loop`

The core autonomous mode. Picks up tickets and feeds them to Claude Code one by one until all tickets are done or a failure occurs.

```bash
harness loop                              # run all tickets
harness loop --max-tickets 3              # stop after 3
harness loop --max-retries 5              # retry failed tickets 5x
harness loop --skill refactor             # apply refactor skill to each ticket
harness loop --pause                      # ask before each ticket
harness loop --dry-run                    # print prompts without running
harness loop --verbose                    # show Claude Code output in real-time
harness loop --model opus                 # use a specific model
```

| Option               | Default | Description                                    |
|----------------------|---------|------------------------------------------------|
| `--max-tickets <n>`  | all     | Stop after N tickets                           |
| `--max-retries <n>`  | 3       | Max retries per ticket before failing           |
| `--max-turns <n>`    | 50      | Max Claude Code turns per ticket               |
| `--model <model>`    | —       | Claude model to use                            |
| `--dry-run`          | false   | Print prompts without running Claude Code      |
| `--skill <name>`     | —       | Include a skill in every ticket prompt         |
| `--pause`            | false   | Pause for confirmation between tickets         |
| `--verbose`          | false   | Show Claude Code output in real-time           |

**How it works:**

1. Reloads QUEUE.json and promotes dependencies
2. Picks the next `ready` ticket
3. Builds a prompt with: ticket content + memory + conventions + optional skill
4. Spawns Claude Code with `--print` mode
5. After Claude Code finishes, runs AC verification via `mark-done.sh`
6. If AC passes: ticket archived, next ticket promoted
7. If AC fails: retries up to `--max-retries` times
8. If all retries exhausted: logs to `memory/bugs.md`, asks whether to skip/stop/retry
9. Prints a final summary with elapsed time and tickets completed

---

### `harness prompt [ticket-id]`

Generate a self-contained prompt for a ticket that you can copy-paste into Claude Code manually.

```bash
harness prompt                         # current ticket
harness prompt 0003-auth-system        # specific ticket
harness prompt --skill review          # include a skill
harness prompt --clipboard             # copy to clipboard
```

| Option              | Description                                      |
|---------------------|--------------------------------------------------|
| `--skill <name>`    | Include a skill in the prompt                    |
| `--clipboard`       | Copy to clipboard (needs xclip or pbcopy)        |

The generated prompt includes the ticket content, code conventions from memory, the memory index, workflow rules, and optional skill instructions — everything Claude Code needs to work autonomously.

---

### `harness memory <subcommand>`

Search, update, or view the persistent memory system.

**Search across all memory files:**

```bash
harness memory search "auth"
harness memory search "database migration"
```

**Add a note to memory:**

```bash
harness memory update decision "Chose JWT over session-based auth for stateless API"
harness memory update bug "Login redirect fails on Safari — CORS issue"
harness memory update convention "All API routes must return { status, data, error } envelope"
harness memory update log "Completed auth system, moving to frontend"
harness memory update architecture "Using Redis for session cache, PostgreSQL for persistence"
```

Categories: `decision`, `bug`, `convention`, `log`, `architecture`

**Show the memory index:**

```bash
harness memory show
```

---

### `harness skill <subcommand>`

Manage and run reusable skills.

**List available skills:**

```bash
harness skill list
```

Example output:

```
  Available Skills:

  [prompt] refactor — Analyze code and suggest refactoring improvements
  [prompt] add-tests — Generate comprehensive tests for existing code
  [prompt] review — Thorough code review with security, performance, and style checks
  [hybrid] deploy-check — Pre-deployment verification: build, tests, secrets scan, Docker check
```

**Run a skill:**

```bash
harness skill run refactor
harness skill run deploy-check
harness skill run add-tests src/api/users.ts
harness skill run review --dry-run
```

**Create a new skill:**

```bash
harness skill create my-skill
harness skill create db-migrate --type hybrid
harness skill create lint-fix --type script
```

| Type     | Description                                            |
|----------|--------------------------------------------------------|
| `prompt` | Sent to Claude Code as instructions                    |
| `script` | Runs a bash script (run.sh)                            |
| `hybrid` | Runs the script first, then sends the prompt           |

**Show skill details:**

```bash
harness skill info refactor
```

---

### `harness verify [ticket-id]`

Run acceptance verification for a ticket without marking it done. Useful for checking progress mid-work.

```bash
harness verify                        # current ticket
harness verify 0002-create-api        # specific ticket
```

---

## Memory System

The harness uses a 4-layer memory system that persists across sessions and survives context compaction.

### Layer 1: CLAUDE.md (always loaded)

The top-level project file. Claude Code loads this automatically on every session. Keep it under 200 lines. Contains: project identity, tech stack, deadline, harness workflow instructions, critical rules, and links to memory files.

### Layer 2: memory/MEMORY.md (loaded on session start)

The memory index. Loaded by the `SessionStart` hook on every new session, resume, or compaction recovery. Contains: current ticket status, quick links to all memory files, last 3-5 key decisions, and current blockers.

### Layer 3: memory/*.md (loaded on demand)

Detailed files searched with `harness memory search "query"`:

| File                    | Purpose                                           |
|-------------------------|---------------------------------------------------|
| `architecture.md`       | System design, data flow, tech decisions          |
| `conventions.md`        | Code style, naming, import rules, test patterns   |
| `progress.md`           | Done / in-progress / blocked with ticket IDs      |
| `bugs.md`               | Known issues + root cause + workaround + fix ID   |
| `daily-log.md`          | Timestamped session notes                         |

### Layer 4: memory/archives/ (cold storage)

Archived daily logs. Before each context compaction, the `PreCompact` hook archives the current daily log to `archives/session-{timestamp}.md` and resets the working daily log. Searchable but never auto-loaded.

### How memory flows

```
Session starts → SessionStart hook loads MEMORY.md + current ticket
  ↓
Claude works → searches memory as needed → updates memory with findings
  ↓
Context compacts → PreCompact hook archives daily-log → syncs progress.md
  ↓
Session resumes → SessionStart hook reloads MEMORY.md (context restored)
```

---

## Ticket System

### Ticket format

Each ticket is a markdown file in `tickets/`:

```markdown
# Ticket 0002-create-api: Create User API

**Status:** ready
**Dependencies:** 0001 ✓
**Size:** Medium

## Summary
Build the user CRUD API with endpoints for list, get, create, update, delete.

## Acceptance Criteria
- [ ] `build`: TypeScript compiles with no errors
- [ ] `build`: All existing tests pass
- [ ] `api`: GET /api/users returns 200 + JSON array
- [ ] `api`: GET /api/users/999 returns 404
- [ ] `unit_test`: tests/api/users.test.ts passes

## Files to Touch
- src/api/users.ts (new)
- src/tests/api/users.test.ts (new)
- src/index.ts (register route)

## Implementation Notes
[Filled during work]

## Session Notes
[Filled during work]
```

### QUEUE.json (state machine)

The single source of truth for ticket state:

```json
{
  "current_ticket": "0002-create-api",
  "queue": [
    {
      "id": "0001-project-setup",
      "title": "Project Setup",
      "status": "done",
      "completed_at": "2026-03-12T10:30:00Z"
    },
    {
      "id": "0002-create-api",
      "title": "Create User API",
      "status": "in_progress",
      "depends_on": ["1"],
      "assigned_at": "2026-03-12T10:35:00Z"
    },
    {
      "id": "0003-auth-system",
      "title": "Authentication System",
      "status": "backlog",
      "depends_on": ["2"]
    }
  ]
}
```

### Ticket states

```
backlog → ready → in_progress → verifying → done
```

- **backlog**: Dependencies not yet satisfied
- **ready**: All dependencies done, available to pick up
- **in_progress**: Currently being worked on
- **verifying**: AC verification running
- **done**: All AC passed, ticket archived

### Dependency resolution

Dependencies are stored as numeric references (e.g., `"depends_on": ["1", "2"]`). When a ticket completes, the harness checks all backlog tickets and promotes any whose dependencies are fully satisfied. This happens automatically in `next-ticket.sh` and in `loop` mode.

---

## Acceptance Criteria

Every ticket has acceptance criteria that must pass before the ticket can be marked done. The harness supports five AC types:

### `build`

Runs type-check, linter, and test suite. Auto-detects package manager:

- npm/pnpm/yarn/bun projects: `tsc --noEmit` + `npm test`
- Cargo projects: `cargo build --release` + `cargo test`
- Go projects: `go build ./...` + `go test ./...`
- Python projects: `python -m py_compile` + `pytest`

### `api`

Parses AC lines for HTTP method, path, and expected status code. Curls each endpoint and checks the response. Assumes a dev server is running on localhost.

Example AC line: `GET /api/users/123 returns 200 + JSON`

### `unit_test`

Runs specific test files mentioned in the ticket's AC section. Checks for pass/fail and coverage thresholds.

### `visual`

Generates a verification plan for Chrome MCP integration. Outputs instructions for Claude to navigate to URLs, take screenshots, and verify that UI elements render correctly.

### `functional`

Generates a click-through verification plan for Chrome MCP. Outputs flow descriptions: navigate to page, fill form, click button, verify result.

### Running verification

```bash
harness verify 0002             # run all AC for a ticket
harness done 0002               # verify + archive if passing
```

The `verify-all.sh` dispatcher reads the ticket file, identifies AC types from the checkbox prefixes, and calls the matching `verify-*.sh` script for each type.

---

## Claude Code Hooks

The harness configures four Claude Code hooks in `.claude/settings.json`:

### SessionStart

**Trigger:** Every session start, resume, or compaction recovery.

**Action:** Reads `memory/MEMORY.md` and the current ticket, outputs them to stdout. Claude Code injects this into context, so the model always knows the project state and current task.

### PostToolUse

**Trigger:** After every `Edit` or `Write` tool use.

**Action:** If the edited file is `.ts`, `.tsx`, `.js`, or `.jsx`, runs the type-checker. If type-check fails, exits with code 2 (blocks Claude Code and tells it to fix the error). This catches type errors immediately rather than at the end.

### PreCompact

**Trigger:** Before context compaction.

**Action:** Archives the current daily log to `memory/archives/`, syncs progress.md with QUEUE.json state, and resets the daily log template. Ensures no knowledge is lost when the context window compresses.

### Stop

**Trigger:** When Claude Code tries to stop.

**Action:** Checks if the current ticket has unchecked acceptance criteria. If any AC items remain unchecked, exits with code 2 (blocks stopping) and tells Claude which criteria still need work. This is the core enforcement mechanism — the model cannot declare "done" without actually passing verification.

### Hook exit codes

| Code | Meaning                                                    |
|------|------------------------------------------------------------|
| 0    | Allow (stdout injected into context for SessionStart)      |
| 2    | Block (stderr shown to Claude, must fix before proceeding) |

---

## Skills

Skills are reusable capabilities stored in `harness/skills/`. Each skill is a directory containing:

```
harness/skills/my-skill/
├── SKILL.md        # Instructions/prompt template for Claude Code
├── config.json     # Metadata: name, description, type, triggers
└── run.sh          # (optional) Executable script
```

### Built-in skills

| Skill          | Type   | Description                                                    |
|----------------|--------|----------------------------------------------------------------|
| `refactor`     | prompt | Analyze code and suggest refactoring improvements              |
| `add-tests`    | prompt | Generate comprehensive tests for existing code                 |
| `review`       | prompt | Code review with security, performance, and style checks       |
| `deploy-check` | hybrid | Pre-deployment verification: build, tests, secrets, Docker     |

### Skill types

**prompt** — The SKILL.md content is sent to Claude Code as instructions. Claude Code executes the task using its own tools.

**script** — The run.sh script is executed directly in bash. No Claude Code involvement.

**hybrid** — Runs the script first (e.g., for automated checks), then sends the prompt to Claude Code (e.g., for analysis of the results).

### Creating a skill

```bash
harness skill create my-skill --type prompt
```

This scaffolds the directory with template files. Edit `SKILL.md` with your instructions, `config.json` with metadata, and optionally `run.sh` for script-based logic.

### config.json format

```json
{
  "name": "my-skill",
  "description": "What this skill does",
  "type": "prompt",
  "triggers": ["my-skill", "alias"],
  "model": "sonnet",
  "maxTurns": 30
}
```

### Using skills with loop mode

```bash
harness loop --skill refactor
```

This includes the skill's SKILL.md content in every ticket prompt, so Claude Code applies the skill's instructions alongside each ticket's requirements.

---

## Loop Mode (Autonomous)

Loop mode is the flagship feature. It runs your entire ticket queue through Claude Code without human intervention.

### What happens in a loop iteration

1. **Reload** QUEUE.json (picks up changes from previous iteration)
2. **Promote** backlog tickets whose dependencies are now satisfied
3. **Pick** the next `ready` ticket
4. **Build prompt** combining: ticket content + memory index + conventions + optional skill
5. **Spawn** Claude Code with `--print` mode (non-interactive, tool access)
6. **Wait** for Claude Code to finish (up to `--max-turns` API calls)
7. **Verify** acceptance criteria via `mark-done.sh`
8. **If pass:** archive ticket, update QUEUE.json, promote dependencies, move to next
9. **If fail:** retry up to `--max-retries` times
10. **If exhausted:** log to bugs.md, ask user whether to skip/stop/retry

### Failure handling

When a ticket fails after all retries, the harness logs the failure to `memory/bugs.md` with a timestamp and prompts you to choose:

- **Skip** — move on to the next ready ticket
- **Stop** — end the loop, leaving the queue in its current state
- **Retry** — try the same ticket again

### Example session

```bash
$ harness loop --max-tickets 5 --verbose

┌─────────────────────────────────────────┐
│  ⚡ Bulletproof Harness                  │
│  Autonomous dev with Claude Code        │
└─────────────────────────────────────────┘

  Starting autonomous loop...

  ═══ Ticket 1: 0001-project-setup ═══
  Initialize project with TypeScript and build tools

  [1/2] Running Claude Code (max 50 turns)...
  [2/2] Verifying acceptance criteria...
  ✓ 0001-project-setup — DONE

  ═══ Ticket 2: 0002-database-schema ═══
  Design and implement database schema

  [1/2] Running Claude Code (max 50 turns)...
  [2/2] Verifying acceptance criteria...
  ✓ 0002-database-schema — DONE

  ═══ Loop Summary ═══
  Tickets completed: 2
  Elapsed: 4m 32s
```

---

## Plan Wizard

The `harness plan` command converts a project idea into a structured ticket queue. It supports three input modes.

### Plan format

Whether generated by AI or written manually, the plan follows this format in `tickets/_plan.md`:

```markdown
### Task 1: Project Setup
Summary: Initialize monorepo with TypeScript, configure build tools
Files: package.json, tsconfig.json, .gitignore
AC: build
Depends: none
Size: Small
---
### Task 2: Database Schema
Summary: Design user and session tables, set up migrations
Files: src/db/schema.ts, src/db/migrations/001-init.sql
AC: build, unit_test
Depends: 1
Size: Medium
---
### Task 3: Authentication API
Summary: JWT-based auth with login, register, refresh endpoints
Files: src/api/auth.ts, src/middleware/auth.ts
AC: build, api, unit_test
Depends: 1, 2
Size: Large
```

### Field reference

| Field     | Description                                                        |
|-----------|--------------------------------------------------------------------|
| `Summary` | 1-2 sentence description of what to build                         |
| `Files`   | Comma-separated list of files to create or modify                  |
| `AC`      | Comma-separated AC types: build, api, unit_test, visual, functional|
| `Depends` | Task numbers this depends on (or "none")                           |
| `Size`    | Small (1h), Medium (2-3h), or Large (3h+)                          |

### Ticket generation

Running `harness plan --from-file` (or the final step of the interactive wizard) parses `_plan.md` and creates:

- Individual ticket files: `tickets/0001-project-setup.md`, `tickets/0002-database-schema.md`, etc.
- QUEUE.json entries with correct dependency references
- Status set to `ready` if dependencies are met, `backlog` otherwise

---

## Directory Structure

```
project-root/
├── CLAUDE.md                            # Master instructions (<200 lines)
├── .claude/
│   └── settings.json                    # Hook configuration
├── memory/
│   ├── MEMORY.md                        # Index + current status
│   ├── architecture.md                  # Design decisions, data flow
│   ├── conventions.md                   # Code style, naming, patterns
│   ├── progress.md                      # Done / in-progress / blocked
│   ├── bugs.md                          # Known issues + workarounds
│   ├── daily-log.md                     # Session notes
│   └── archives/                        # Archived daily logs
├── tickets/
│   ├── _plan.md                         # Master build plan
│   ├── QUEUE.json                       # Ticket state machine
│   ├── 0001-project-setup.md            # Individual tickets
│   ├── 0002-database-schema.md
│   └── completed/                       # Archived done tickets
└── harness/
    ├── bin/
    │   ├── init-harness.sh              # One-time setup
    │   ├── session-start.sh             # Hook: load memory + ticket
    │   ├── post-edit-typecheck.sh       # Hook: type-check after edits
    │   ├── pre-compact-save.sh          # Hook: archive before compact
    │   ├── stop-verify.sh               # Hook: verify AC before stop
    │   ├── next-ticket.sh               # Pop next ready ticket
    │   ├── mark-done.sh                 # Verify AC + archive + advance
    │   ├── search-memory.sh             # Grep across memory files
    │   ├── update-memory.sh             # Append to memory files
    │   └── generate-tickets.sh          # Parse _plan.md into tickets
    ├── acceptance/
    │   ├── verify-all.sh                # Dispatcher
    │   ├── verify-build.sh              # tsc + lint + test
    │   ├── verify-api.sh                # curl endpoints
    │   ├── verify-visual.sh             # Chrome MCP screenshot
    │   ├── verify-functional.sh         # Chrome MCP click-through
    │   └── verify-unit_test.sh          # Run specific test files
    ├── skills/
    │   ├── refactor/                    # Built-in: code cleanup
    │   ├── add-tests/                   # Built-in: test generation
    │   ├── review/                      # Built-in: code review
    │   └── deploy-check/                # Built-in: pre-deploy checks
    └── cli/
        ├── package.json
        ├── tsconfig.json
        └── src/
            ├── index.ts                 # CLI entry point
            ├── types.d.ts               # Module declarations
            ├── commands/                 # 10 command files
            └── lib/                     # Shared utilities
```

---

## Configuration

### .claude/settings.json

This file configures Claude Code hooks. It's created automatically by `harness init`:

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup|resume|compact",
      "hooks": [{
        "type": "command",
        "command": "bash harness/bin/session-start.sh"
      }]
    }],
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "bash harness/bin/post-edit-typecheck.sh"
      }]
    }],
    "PreCompact": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "bash harness/bin/pre-compact-save.sh"
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "bash harness/bin/stop-verify.sh"
      }]
    }]
  }
}
```

### CLAUDE.md

Edit this file with your project-specific details. The template created by `harness init` includes placeholders for project description, tech stack, architecture, and deadline. Keep it under 200 lines — Claude Code loads this entire file into context on every interaction.

### memory/conventions.md

Define your code style, naming conventions, import patterns, testing patterns, and project-specific rules here. This file is injected into every ticket prompt in loop mode, so Claude Code follows your conventions consistently.

---

## Extending the Harness

### Adding a new AC type

1. Create `harness/acceptance/verify-mytype.sh`
2. The script receives the ticket file path and project root as arguments
3. Exit 0 for pass, non-zero for fail
4. Use the AC type in ticket files: `- [ ] \`mytype\`: description`
5. The `verify-all.sh` dispatcher will auto-detect and call it

### Adding a new hook

Edit `.claude/settings.json` to add hooks at any lifecycle point. Available hook types:

- `SessionStart` — when Claude Code starts or resumes
- `PostToolUse` — after specific tools are used (filter with `matcher`)
- `PreCompact` — before context compaction
- `Stop` — when Claude Code tries to stop

### Custom skills

Create a new skill directory in `harness/skills/` with SKILL.md, config.json, and optionally run.sh. Use `harness skill create <name>` for scaffolding. Skills can be composed with tickets in loop mode using `--skill <name>`.

### Integrating with CI/CD

The shell scripts are self-contained and can be called from CI pipelines:

```bash
# In CI: verify all tickets have passing AC
for ticket in tickets/0*.md; do
  bash harness/acceptance/verify-all.sh "$ticket"
done

# Or run the deploy check skill
bash harness/skills/deploy-check/run.sh
```

---

## Command Reference (Quick)

| Command                        | Description                               |
|--------------------------------|-------------------------------------------|
| `harness init [name]`          | Initialize harness in current directory    |
| `harness plan`                 | Interactive plan wizard                    |
| `harness plan --prd <file>`    | Generate plan from PRD                     |
| `harness plan --from-file`     | Generate tickets from _plan.md             |
| `harness next`                 | Pick up next ready ticket                  |
| `harness done [id]`            | Verify AC + archive + advance              |
| `harness status`               | Show queue + progress bar                  |
| `harness loop`                 | Autonomous mode                            |
| `harness prompt [id]`          | Print Claude Code prompt for a ticket      |
| `harness memory search <q>`    | Search memory files                        |
| `harness memory update <c> <n>`| Add a note to memory                       |
| `harness memory show`          | Print memory index                         |
| `harness skill list`           | List available skills                      |
| `harness skill run <name>`     | Run a skill                                |
| `harness skill create <name>`  | Scaffold a new skill                       |
| `harness skill info <name>`    | Show skill details                         |
| `harness verify [id]`          | Run AC verification                        |
