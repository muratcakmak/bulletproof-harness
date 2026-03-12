#!/usr/bin/env bash
set -euo pipefail

# deploy-check — Pre-deployment verification
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0
WARN=0

check() {
  local label="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    FAIL=$((FAIL + 1))
  fi
}

warn_check() {
  local label="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  ⚠ $label"
    WARN=$((WARN + 1))
  fi
}

echo ""
echo "  Deploy Check — $PROJECT_ROOT"
echo "  ──────────────────────────────────"
echo ""

# Build check
if [ -f "package.json" ]; then
  if command -v pnpm &>/dev/null; then
    check "Build (pnpm)" pnpm run build
  elif command -v npm &>/dev/null; then
    check "Build (npm)" npm run build
  fi
fi

if [ -f "Cargo.toml" ]; then
  check "Build (cargo)" cargo build --release
fi

if [ -f "go.mod" ]; then
  check "Build (go)" go build ./...
fi

# Test check
if [ -f "package.json" ] && grep -q '"test"' package.json; then
  check "Tests pass" npm test
fi

# Secrets scan
warn_check "Possible secrets in code" grep -rn "AKIA\|sk-\|password.*=.*['\"]" src/ --include="*.ts" --include="*.js" --include="*.py"

# .env.example check
if [ -f ".env.example" ]; then
  echo "  ✓ .env.example exists"
  PASS=$((PASS + 1))
else
  echo "  ⚠ No .env.example found"
  WARN=$((WARN + 1))
fi

# Docker check
if [ -f "Dockerfile" ] || [ -f "deploy/Dockerfile" ]; then
  DOCKERFILE=$(ls Dockerfile deploy/Dockerfile 2>/dev/null | head -1)
  check "Docker build" docker build -f "$DOCKERFILE" -t deploy-check-test .
fi

# Debug code check
DEBUG_COUNT=$(grep -rn "console\.log\|debugger\|TODO:" src/ --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | wc -l || echo "0")
if [ "$DEBUG_COUNT" -gt 0 ]; then
  echo "  ⚠ $DEBUG_COUNT debug/TODO statements in source"
  WARN=$((WARN + 1))
else
  echo "  ✓ No debug statements"
  PASS=$((PASS + 1))
fi

echo ""
echo "  ──────────────────────────────────"
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "  ✗ DEPLOY BLOCKED — fix failures above"
  exit 1
else
  echo "  ✓ Ready to deploy"
  exit 0
fi
