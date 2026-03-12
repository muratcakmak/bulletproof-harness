# Bulletproof Harness

Autonomous ticket-driven development orchestrator for Claude Code.

Turn any project into a structured, autonomous build pipeline with persistent memory, dependency-aware tickets, enforced acceptance criteria, and Claude Code hooks that prevent the model from cutting corners.

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/muratcakmak/bulletproof-harness/main/install-remote.sh)"
```

That's it. The installer clones the repo to `~/.bulletproof-harness`, installs the `harness` CLI globally, and walks you through initializing your first project.

### Requirements

- Node.js 18+
- git
- jq
- Claude Code CLI (optional — needed for `loop` and `plan` modes)

### Manual install

```bash
git clone https://github.com/muratcakmak/bulletproof-harness.git ~/.bulletproof-harness
cd ~/.bulletproof-harness/cli
npm install && npm run build && npm link
```

### Uninstall

```bash
bash ~/.bulletproof-harness/uninstall.sh
```

## Quick Start

```bash
# Initialize a new project
cd your-project
harness init "My Project"

# Edit your project details
$EDITOR CLAUDE.md
$EDITOR memory/conventions.md

# Generate tickets from a PRD or interactively
harness plan --prd requirements.md
# OR
harness plan

# Let Claude Code build it autonomously
harness loop
```

## Why

Claude Code is powerful but unstructured. Without guardrails it declares tasks "done" prematurely, loses context across sessions, repeats mistakes, and ignores conventions. Bulletproof Harness fixes all of that:

- **Memory that survives compaction** — 4-layer file-based memory hooked into Claude Code's lifecycle
- **Tickets with real dependencies** — state-machine queue where tickets auto-promote when deps complete
- **Enforced acceptance criteria** — type-check, API curl, unit tests, visual screenshots, click-through verification must all pass
- **Stop hook** — Claude Code cannot stop until AC is verified
- **Loop mode** — feed your entire queue through Claude Code autonomously with retries and skill injection

## How It Works

```
┌──────────────────────────────────────────────────┐
│                   CLAUDE.md                       │
│            (project rules, <200 lines)            │
├──────────────┬──────────────┬────────────────────┤
│    MEMORY    │   TICKETS    │   ACCEPTANCE        │
│   4-layer    │  state       │   build / api /     │
│   persistent │  machine     │   unit_test /       │
│   searchable │  with deps   │   visual /          │
│              │              │   functional        │
├──────────────┴──────────────┴────────────────────┤
│               CLAUDE CODE HOOKS                   │
│   SessionStart → PostToolUse → Stop → PreCompact  │
└──────────────────────────────────────────────────┘
```

**SessionStart** loads memory + current ticket into context.
**PostToolUse** type-checks after every file edit, blocks if it fails.
**Stop** verifies AC — Claude cannot declare done without passing.
**PreCompact** archives the daily log so nothing is lost.

## Commands

| Command                         | What it does                                    |
|---------------------------------|-------------------------------------------------|
| `harness init [name]`           | Initialize harness in current directory          |
| `harness plan`                  | Generate tickets (wizard / PRD / from-file)      |
| `harness next`                  | Pick up next ready ticket                        |
| `harness done [id]`             | Verify AC + archive + advance queue              |
| `harness status`                | Progress bar + color-coded queue                 |
| `harness loop`                  | Autonomous mode — runs all tickets via Claude    |
| `harness prompt [id]`           | Print a copy-paste prompt for a ticket           |
| `harness memory search <q>`     | Search across all memory files                   |
| `harness memory update <c> <n>` | Add a note (decision/bug/convention/log/arch)    |
| `harness skill list`            | List available skills                            |
| `harness skill run <name>`      | Run a skill                                      |
| `harness verify [id]`           | Run AC checks without marking done               |

## Loop Mode

The flagship feature. Runs your entire ticket queue through Claude Code hands-free:

```bash
harness loop                          # run everything
harness loop --max-tickets 5          # stop after 5
harness loop --skill refactor         # apply a skill to each ticket
harness loop --pause                  # confirm between tickets
harness loop --verbose --max-retries 5
```

## Built-in Skills

| Skill          | Type   | Does what                                         |
|----------------|--------|---------------------------------------------------|
| `refactor`     | prompt | Code cleanup and improvement suggestions          |
| `add-tests`    | prompt | Generate comprehensive tests for existing code    |
| `review`       | prompt | Security, performance, and style code review      |
| `deploy-check` | hybrid | Pre-deploy: build, tests, secrets scan, Docker    |

Create your own: `harness skill create my-skill --type prompt`

## Environment Variables

| Variable          | Default                          | Description                    |
|-------------------|----------------------------------|--------------------------------|
| `HARNESS_HOME`    | `~/.bulletproof-harness`         | Installation directory         |
| `HARNESS_REPO`    | GitHub URL                       | Override repo URL for install  |
| `HARNESS_BRANCH`  | `main`                           | Override branch for install    |

## Full Documentation

See **[HARNESS-DOCS.md](./HARNESS-DOCS.md)** for the complete reference.

## License

MIT
