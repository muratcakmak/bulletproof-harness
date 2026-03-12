#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bulletproof Harness — Uninstaller
# Removes the global CLI and ~/.bulletproof-harness
# Does NOT remove harness files from individual projects.
# ============================================================================

INSTALL_DIR="${HARNESS_HOME:-$HOME/.bulletproof-harness}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo ""
echo -e "${BOLD}Bulletproof Harness — Uninstaller${NC}"
echo ""

# Unlink CLI
if command -v harness &>/dev/null; then
  echo "Removing global CLI link..."
  cd "$INSTALL_DIR/cli" 2>/dev/null && npm unlink --silent 2>/dev/null || true
  echo -e "  ${GREEN}✓${NC} CLI unlinked"
fi

# Remove install directory
if [ -d "$INSTALL_DIR" ]; then
  echo "Removing $INSTALL_DIR..."
  rm -rf "$INSTALL_DIR"
  echo -e "  ${GREEN}✓${NC} Removed"
else
  echo -e "  ${DIM}Nothing to remove at $INSTALL_DIR${NC}"
fi

# Clean shell RC
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if [ -f "$rc" ] && grep -q "HARNESS_HOME" "$rc"; then
    sed -i.bak '/# Bulletproof Harness/d;/HARNESS_HOME/d' "$rc"
    rm -f "${rc}.bak"
    echo -e "  ${GREEN}✓${NC} Cleaned $rc"
  fi
done

echo ""
echo -e "${GREEN}Uninstalled.${NC} Project-level harness files (memory/, tickets/, etc.) are untouched."
echo ""
