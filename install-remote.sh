#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bulletproof Harness — Remote Installer
#
# Install with:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/USER/bulletproof-harness/main/install-remote.sh)"
#
# What it does:
#   1. Clones the repo to ~/.bulletproof-harness
#   2. Installs the CLI globally (npm link)
#   3. Optionally initializes the current directory as a harness project
# ============================================================================

REPO_URL="${HARNESS_REPO:-https://github.com/USER/bulletproof-harness.git}"
INSTALL_DIR="${HARNESS_HOME:-$HOME/.bulletproof-harness}"
BRANCH="${HARNESS_BRANCH:-main}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║      ⚡ Bulletproof Harness Installer      ║"
echo "  ║   Autonomous dev orchestrator for Claude   ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# --- Check dependencies ---
echo -e "${BOLD}Checking dependencies...${NC}"

missing=()

if ! command -v git &>/dev/null; then
  missing+=("git")
fi

if ! command -v node &>/dev/null; then
  missing+=("node (v18+)")
fi

if ! command -v npm &>/dev/null; then
  missing+=("npm")
fi

if ! command -v jq &>/dev/null; then
  missing+=("jq")
fi

if [ ${#missing[@]} -gt 0 ]; then
  echo -e "${RED}Missing required dependencies:${NC}"
  for dep in "${missing[@]}"; do
    echo -e "  ${RED}✗${NC} $dep"
  done
  echo ""
  echo "Install them first, then re-run this script."
  echo ""

  # Suggest install commands
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${DIM}On macOS:  brew install git node jq${NC}"
  elif command -v apt &>/dev/null; then
    echo -e "${DIM}On Ubuntu: sudo apt install git nodejs npm jq${NC}"
  fi
  exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
  echo -e "${RED}Node.js 18+ required (found v$(node -v))${NC}"
  exit 1
fi

echo -e "  ${GREEN}✓${NC} git"
echo -e "  ${GREEN}✓${NC} node $(node -v)"
echo -e "  ${GREEN}✓${NC} npm $(npm -v)"
echo -e "  ${GREEN}✓${NC} jq $(jq --version)"

# Check for Claude Code (optional)
if command -v claude &>/dev/null; then
  echo -e "  ${GREEN}✓${NC} claude code CLI"
else
  echo -e "  ${YELLOW}○${NC} claude code CLI ${DIM}(optional — needed for loop mode)${NC}"
fi
echo ""

# --- Clone or update ---
if [ -d "$INSTALL_DIR/.git" ]; then
  echo -e "${BOLD}Updating existing installation...${NC}"
  cd "$INSTALL_DIR"
  git fetch origin "$BRANCH" --quiet
  git reset --hard "origin/$BRANCH" --quiet
  echo -e "  ${GREEN}✓${NC} Updated to latest"
else
  if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Removing old installation at $INSTALL_DIR${NC}"
    rm -rf "$INSTALL_DIR"
  fi

  echo -e "${BOLD}Downloading Bulletproof Harness...${NC}"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR" --quiet
  echo -e "  ${GREEN}✓${NC} Downloaded to $INSTALL_DIR"
fi
echo ""

# --- Install CLI ---
echo -e "${BOLD}Installing CLI...${NC}"
cd "$INSTALL_DIR/cli"
npm install --silent 2>&1 | tail -1
npm run build --silent 2>&1 | tail -1
npm link --silent 2>&1 || {
  echo -e "  ${YELLOW}!${NC} npm link failed (may need sudo)"
  echo -e "  ${DIM}Try: sudo npm link${NC}"
  echo -e "  ${DIM}Or add to PATH: export PATH=\"$INSTALL_DIR/cli/node_modules/.bin:\$PATH\"${NC}"
}
echo -e "  ${GREEN}✓${NC} CLI installed globally"
echo ""

# --- Add shell alias for updating ---
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
  if ! grep -q "HARNESS_HOME" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# Bulletproof Harness" >> "$SHELL_RC"
    echo "export HARNESS_HOME=\"$INSTALL_DIR\"" >> "$SHELL_RC"
    echo -e "  ${GREEN}✓${NC} Added HARNESS_HOME to $SHELL_RC"
  fi
fi

# --- Ask about initializing current project ---
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

INIT_HERE=""
if [ -t 0 ]; then
  # Interactive mode
  read -rp "  Initialize a project now? (Y/n): " INIT_HERE
  INIT_HERE="${INIT_HERE:-Y}"
else
  # Non-interactive (piped from curl) — skip
  INIT_HERE="n"
fi

if [[ "$INIT_HERE" =~ ^[Yy] ]]; then
  echo ""

  TARGET_DIR=""
  read -rp "  Project directory (. for current): " TARGET_DIR
  TARGET_DIR="${TARGET_DIR:-.}"

  if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
  fi

  PROJECT_NAME=""
  read -rp "  Project name: " PROJECT_NAME
  PROJECT_NAME="${PROJECT_NAME:-$(basename "$(cd "$TARGET_DIR" && pwd)")}"

  echo ""
  bash "$INSTALL_DIR/install.sh" "$TARGET_DIR" "$PROJECT_NAME"
fi

# --- Done ---
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔═══════════════════════════════════════════╗"
echo "  ║      ✓ Installation complete!              ║"
echo "  ╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "  ${BOLD}Quick start:${NC}"
echo ""
echo -e "    ${CYAN}cd your-project${NC}"
echo -e "    ${CYAN}harness init \"My Project\"${NC}"
echo -e "    ${CYAN}harness plan${NC}"
echo -e "    ${CYAN}harness loop${NC}"
echo ""
echo -e "  ${BOLD}Update:${NC}"
echo -e "    ${DIM}Re-run this script or: cd $INSTALL_DIR && git pull && cd cli && npm run build${NC}"
echo ""
echo -e "  ${BOLD}Uninstall:${NC}"
echo -e "    ${DIM}rm -rf $INSTALL_DIR && npm unlink -g harness-cli${NC}"
echo ""
echo -e "  ${BOLD}Docs:${NC}  $INSTALL_DIR/HARNESS-DOCS.md"
echo ""
