#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bulletproof Harness — Installer
#
# Copies the harness into a target project and initializes everything.
#
# Usage:
#   ./install.sh /path/to/your-project "Project Name"
#   ./install.sh .                                      # current directory
#   ./install.sh                                        # prompts for path
# ============================================================================

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  ⚡ Bulletproof Harness — Installer"
echo ""

# --- Get target ---
TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  read -rp "  Target project directory: " TARGET
fi

if [ ! -d "$TARGET" ]; then
  echo "  Creating $TARGET ..."
  mkdir -p "$TARGET"
fi

TARGET="$(cd "$TARGET" && pwd)"
PROJECT_NAME="${2:-$(basename "$TARGET")}"

echo "  Installing into: $TARGET"
echo "  Project name:    $PROJECT_NAME"
echo ""

# --- Copy harness scripts ---
echo "[1/4] Copying harness scripts..."
mkdir -p "$TARGET/harness"
cp -r "$HARNESS_DIR/bin" "$TARGET/harness/"
cp -r "$HARNESS_DIR/acceptance" "$TARGET/harness/"
cp -r "$HARNESS_DIR/skills" "$TARGET/harness/"

# --- Copy CLI source (users build it themselves) ---
echo "[2/4] Copying CLI source..."
mkdir -p "$TARGET/harness/cli"
cp "$HARNESS_DIR/cli/package.json" "$TARGET/harness/cli/"
cp "$HARNESS_DIR/cli/tsconfig.json" "$TARGET/harness/cli/"
cp -r "$HARNESS_DIR/cli/src" "$TARGET/harness/cli/"

# --- Make scripts executable ---
echo "[3/4] Setting permissions..."
chmod +x "$TARGET"/harness/bin/*.sh 2>/dev/null || true
chmod +x "$TARGET"/harness/acceptance/*.sh 2>/dev/null || true

# --- Run init to scaffold memory, tickets, CLAUDE.md, hooks ---
echo "[4/4] Initializing project scaffolding..."
bash "$TARGET/harness/bin/init-harness.sh" "$PROJECT_NAME"

echo ""
echo "================================================"
echo "  Installation complete!"
echo "================================================"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Edit project details:"
echo "     \$EDITOR $TARGET/CLAUDE.md"
echo "     \$EDITOR $TARGET/memory/conventions.md"
echo ""
echo "  2. Install the CLI (optional but recommended):"
echo "     cd $TARGET/harness/cli"
echo "     npm install && npm run build && npm link"
echo ""
echo "  3. Create your build plan:"
echo "     harness plan --prd your-prd.md"
echo "     # or: harness plan  (interactive wizard)"
echo "     # or: edit $TARGET/tickets/_plan.md manually"
echo ""
echo "  4. Start building:"
echo "     harness loop          # autonomous mode"
echo "     harness next          # one ticket at a time"
echo ""
