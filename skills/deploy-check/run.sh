#!/usr/bin/env bash
set -euo pipefail

# deploy-check — Pre-deployment verification for Cloudflare
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
echo "  Cloudflare Deploy Check — $PROJECT_ROOT"
echo "  ──────────────────────────────────"
echo ""

# ─── Build check ───────────────────────────────────────────
if [ -f "package.json" ]; then
  if command -v pnpm &>/dev/null; then
    check "Build (pnpm)" pnpm run build
  elif command -v npm &>/dev/null; then
    check "Build (npm)" npm run build
  fi
fi

# ─── Test check ────────────────────────────────────────────
if [ -f "package.json" ] && grep -q '"test"' package.json; then
  check "Tests pass" npm test
fi

# ─── Wrangler types ────────────────────────────────────────
if command -v wrangler &>/dev/null || [ -f "node_modules/.bin/wrangler" ]; then
  check "Wrangler types" npx wrangler types
fi

# ─── Secrets scan ──────────────────────────────────────────
warn_check "Possible secrets in code" grep -rn "AKIA\|sk-\|password.*=.*['\"]" src/ functions/ --include="*.ts" --include="*.js" 2>/dev/null

# ─── Environment files check ──────────────────────────────
if [ -f ".dev.vars" ] || [ -f ".dev.vars.example" ]; then
  echo "  ✓ .dev.vars exists (Cloudflare secrets)"
  PASS=$((PASS + 1))
elif [ -f ".env.example" ]; then
  echo "  ✓ .env.example exists"
  PASS=$((PASS + 1))
else
  echo "  ⚠ No .dev.vars or .env.example found"
  WARN=$((WARN + 1))
fi

# ─── Cloudflare / Wrangler check ──────────────────────────
WRANGLER_CONFIG=""
for cfg in wrangler.toml wrangler.jsonc wrangler.json; do
  if [ -f "$cfg" ]; then
    WRANGLER_CONFIG="$cfg"
    break
  fi
done

if [ -n "$WRANGLER_CONFIG" ]; then
  echo "  ✓ Wrangler config found: $WRANGLER_CONFIG"
  PASS=$((PASS + 1))

  # Check wrangler CLI is available
  if command -v wrangler &>/dev/null || [ -f "node_modules/.bin/wrangler" ]; then
    echo "  ✓ Wrangler CLI available"
    PASS=$((PASS + 1))
  else
    echo "  ✗ Wrangler CLI not found (npm i -g wrangler)"
    FAIL=$((FAIL + 1))
  fi

  # D1 migrations check — if D1 bindings are configured, migrations dir should exist with non-empty files
  if grep -q "d1_databases" "$WRANGLER_CONFIG" 2>/dev/null || grep -q '"d1_databases"' "$WRANGLER_CONFIG" 2>/dev/null; then
    if [ -d "migrations" ] && ls migrations/*.sql &>/dev/null 2>&1; then
      # Verify .sql files are non-empty
      EMPTY_COUNT=0
      for sql_file in migrations/*.sql; do
        if [ ! -s "$sql_file" ]; then
          echo "  ✗ Empty migration file: $sql_file"
          EMPTY_COUNT=$((EMPTY_COUNT + 1))
        fi
      done
      if [ "$EMPTY_COUNT" -eq 0 ]; then
        echo "  ✓ D1 migrations found and non-empty"
        PASS=$((PASS + 1))
      else
        FAIL=$((FAIL + EMPTY_COUNT))
      fi
    else
      echo "  ✗ D1 bindings configured but no migrations/ directory with .sql files"
      FAIL=$((FAIL + 1))
    fi
  fi

  # Durable Objects check — if DO bindings are configured, verify class exports
  if grep -q "durable_objects" "$WRANGLER_CONFIG" 2>/dev/null || grep -q '"durable_objects"' "$WRANGLER_CONFIG" 2>/dev/null; then
    DO_CLASSES=""
    if [[ "$WRANGLER_CONFIG" == *.toml ]]; then
      DO_CLASSES=$(grep -oP 'class_name\s*=\s*"\K[^"]+' "$WRANGLER_CONFIG" 2>/dev/null || echo "")
    else
      DO_CLASSES=$(grep -oP '"class_name"\s*:\s*"\K[^"]+' "$WRANGLER_CONFIG" 2>/dev/null || echo "")
    fi

    if [ -n "$DO_CLASSES" ]; then
      for CLASS_NAME in $DO_CLASSES; do
        if grep -rq "export class $CLASS_NAME" src/ functions/ worker/ 2>/dev/null; then
          echo "  ✓ DO class exported: $CLASS_NAME"
          PASS=$((PASS + 1))
        else
          echo "  ✗ DO class not found: export class $CLASS_NAME"
          FAIL=$((FAIL + 1))
        fi
      done
    else
      echo "  ✓ Durable Objects bindings configured"
      PASS=$((PASS + 1))
    fi
  fi

  # .dev.vars check for Cloudflare secrets
  if [ -f ".dev.vars" ]; then
    echo "  ✓ .dev.vars exists (local secrets)"
    PASS=$((PASS + 1))
  else
    echo "  ⚠ No .dev.vars file (needed for local dev secrets)"
    WARN=$((WARN + 1))
  fi

  # Dry-run deploy validation
  if command -v wrangler &>/dev/null || [ -f "node_modules/.bin/wrangler" ]; then
    check "Wrangler deploy dry-run" npx wrangler deploy --dry-run 2>/dev/null || \
      check "Wrangler pages deploy dry-run" npx wrangler pages deploy dist --dry-run 2>/dev/null || true
  fi
else
  echo "  ✗ No wrangler config found (wrangler.toml / wrangler.jsonc / wrangler.json)"
  FAIL=$((FAIL + 1))
fi

# ─── Debug code check ─────────────────────────────────────
DEBUG_COUNT=$(grep -rn "console\.log\|debugger\|TODO:" src/ functions/ --include="*.ts" --include="*.tsx" --include="*.js" 2>/dev/null | wc -l || echo "0")
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
