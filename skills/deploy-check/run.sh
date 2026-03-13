#!/usr/bin/env bash
set -euo pipefail

# deploy-check — Pre-deployment verification (auto-detects project type)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="${HARNESS_HOME:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$HARNESS_DIR/.." && pwd)}"
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

# --- Detect package manager ---
PM=""
if [ -f "pnpm-lock.yaml" ]; then PM="pnpm"
elif [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then PM="bun"
elif [ -f "yarn.lock" ]; then PM="yarn"
elif [ -f "package.json" ]; then PM="npm"
fi

echo ""
echo "  Deploy Check — $PROJECT_ROOT"
echo "  ──────────────────────────────────"
echo ""

# ─── Build check ───────────────────────────────────────────
if [ -n "$PM" ] && [ -f "package.json" ]; then
  if jq -e '.scripts.build' package.json &>/dev/null; then
    check "Build ($PM)" $PM run build
  fi
fi

# ─── Lint check ──────────────────────────────────────────
if [ -n "$PM" ] && [ -f "package.json" ]; then
  if jq -e '.scripts.lint' package.json &>/dev/null; then
    check "Lint ($PM)" $PM run lint
  fi
fi

# ─── Type check ──────────────────────────────────────────
if [ -f "tsconfig.json" ]; then
  if [ -n "$PM" ] && jq -e '.scripts["type-check"] // .scripts["typecheck"]' package.json &>/dev/null 2>&1; then
    check "Type check" $PM run type-check 2>/dev/null || check "Type check" $PM run typecheck 2>/dev/null
  else
    check "Type check (tsc)" npx tsc --noEmit
  fi
fi

# ─── Test check ────────────────────────────────────────────
if [ -n "$PM" ] && [ -f "package.json" ] && jq -e '.scripts.test' package.json &>/dev/null; then
  check "Tests pass" $PM run test
fi

# ─── Secrets scan ──────────────────────────────────────────
SRC_DIRS=""
for d in src/ functions/ worker/ lib/ app/; do
  [ -d "$d" ] && SRC_DIRS="$SRC_DIRS $d"
done
if [ -n "$SRC_DIRS" ]; then
  warn_check "Possible secrets in code" grep -rn "AKIA\|sk-\|password.*=.*['\"]" $SRC_DIRS --include="*.ts" --include="*.js" --include="*.tsx" --include="*.jsx" 2>/dev/null
fi

# ─── Environment files check ──────────────────────────────
if [ -f ".env" ] || [ -f ".env.local" ] || [ -f ".env.example" ]; then
  echo "  ✓ Environment file exists"
  PASS=$((PASS + 1))
elif [ -f ".dev.vars" ] || [ -f ".dev.vars.example" ]; then
  echo "  ✓ .dev.vars exists (Cloudflare secrets)"
  PASS=$((PASS + 1))
else
  echo "  ⚠ No .env or .dev.vars file found"
  WARN=$((WARN + 1))
fi

# ─── Cloudflare / Wrangler checks (auto-detected) ────────
WRANGLER_CONFIG=""
for cfg in wrangler.toml wrangler.jsonc wrangler.json; do
  if [ -f "$cfg" ]; then
    WRANGLER_CONFIG="$cfg"
    break
  fi
done

if [ -n "$WRANGLER_CONFIG" ]; then
  echo ""
  echo "  Cloudflare project detected ($WRANGLER_CONFIG)"
  echo "  ──────────────────────────────────"

  # Check wrangler CLI is available
  if command -v wrangler &>/dev/null || [ -f "node_modules/.bin/wrangler" ]; then
    echo "  ✓ Wrangler CLI available"
    PASS=$((PASS + 1))

    check "Wrangler types" npx wrangler types
  else
    echo "  ✗ Wrangler CLI not found (npm i -g wrangler)"
    FAIL=$((FAIL + 1))
  fi

  # D1 migrations check
  if grep -q "d1_databases" "$WRANGLER_CONFIG" 2>/dev/null || grep -q '"d1_databases"' "$WRANGLER_CONFIG" 2>/dev/null; then
    if [ -d "migrations" ] && ls migrations/*.sql &>/dev/null 2>&1; then
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
      echo "  ✗ D1 bindings configured but no migrations/*.sql files found"
      FAIL=$((FAIL + 1))
    fi
  fi

  # Durable Objects check
  if grep -q "durable_objects" "$WRANGLER_CONFIG" 2>/dev/null || grep -q '"durable_objects"' "$WRANGLER_CONFIG" 2>/dev/null; then
    DO_CLASSES=""
    if [[ "$WRANGLER_CONFIG" == *.toml ]]; then
      DO_CLASSES=$(grep -oE 'class_name[[:space:]]*=[[:space:]]*"[^"]+"' "$WRANGLER_CONFIG" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/' || echo "")
    else
      DO_CLASSES=$(grep -oE '"class_name"[[:space:]]*:[[:space:]]*"[^"]+"' "$WRANGLER_CONFIG" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/' || echo "")
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

  # .dev.vars check
  if [ -f ".dev.vars" ]; then
    echo "  ✓ .dev.vars exists (local secrets)"
    PASS=$((PASS + 1))
  else
    echo "  ⚠ No .dev.vars file (needed for local dev secrets)"
    WARN=$((WARN + 1))
  fi

  # Dry-run deploy
  if command -v wrangler &>/dev/null || [ -f "node_modules/.bin/wrangler" ]; then
    check "Wrangler deploy dry-run" npx wrangler deploy --dry-run 2>/dev/null || \
      check "Wrangler pages deploy dry-run" npx wrangler pages deploy dist --dry-run 2>/dev/null || true
  fi
fi

# ─── Debug code check ─────────────────────────────────────
if [ -n "$SRC_DIRS" ]; then
  DEBUG_COUNT=$(grep -rn "console\.log\|debugger\|TODO:" $SRC_DIRS --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | wc -l || echo "0")
  if [ "$DEBUG_COUNT" -gt 0 ]; then
    echo "  ⚠ $DEBUG_COUNT debug/TODO statements in source"
    WARN=$((WARN + 1))
  else
    echo "  ✓ No debug statements"
    PASS=$((PASS + 1))
  fi
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
