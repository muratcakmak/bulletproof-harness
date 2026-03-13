#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# verify-worker.sh — Cloudflare Worker/Pages verification
# Called by verify-all.sh for AC type: worker
# Validates wrangler config, env types, TypeScript, deploy dry-run,
# D1 migrations, and Durable Object class exports.
# Exit 0 = pass, Exit 1 = fail
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="${HARNESS_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$HARNESS_DIR/.." && pwd)}"
TICKET_ID="${1:-}"
TICKET_FILE="${2:-}"

cd "$PROJECT_ROOT"

ERRORS=0

# --- 1. Wrangler config exists ---
WRANGLER_CONFIG=""
for cfg in wrangler.toml wrangler.jsonc wrangler.json; do
  if [ -f "$cfg" ]; then
    WRANGLER_CONFIG="$cfg"
    break
  fi
done

if [ -z "$WRANGLER_CONFIG" ]; then
  echo "  [worker] ✗ No wrangler.toml / wrangler.jsonc / wrangler.json found"
  exit 1
fi
echo "  [worker] ✓ Wrangler config found: $WRANGLER_CONFIG"

# --- 2. npx wrangler types ---
echo "  [worker] Running wrangler types..."
if command -v wrangler &>/dev/null || [ -f "node_modules/.bin/wrangler" ]; then
  if npx wrangler types 2>&1 | tail -5; then
    echo "  [worker] ✓ wrangler types succeeded"
  else
    echo "  [worker] ✗ wrangler types failed"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "  [worker] ✗ wrangler CLI not found (npm i -g wrangler or npx wrangler)"
  ERRORS=$((ERRORS + 1))
fi

# --- 3. TypeScript compilation ---
if [ -f "tsconfig.json" ]; then
  echo "  [worker] Running tsc --noEmit..."
  if npx tsc --noEmit 2>&1 | tail -10; then
    echo "  [worker] ✓ TypeScript compiles"
  else
    echo "  [worker] ✗ TypeScript compilation failed"
    ERRORS=$((ERRORS + 1))
  fi
fi

# --- 4. Deploy dry-run ---
echo "  [worker] Running deploy dry-run..."
if command -v wrangler &>/dev/null || [ -f "node_modules/.bin/wrangler" ]; then
  if npx wrangler deploy --dry-run 2>&1 | tail -5; then
    echo "  [worker] ✓ wrangler deploy --dry-run passed"
  elif npx wrangler pages deploy dist --dry-run 2>&1 | tail -5; then
    echo "  [worker] ✓ wrangler pages deploy --dry-run passed"
  else
    echo "  [worker] ✗ Deploy dry-run failed"
    ERRORS=$((ERRORS + 1))
  fi
fi

# --- 5. D1 migrations ---
if grep -q "d1_databases" "$WRANGLER_CONFIG" 2>/dev/null || grep -q '"d1_databases"' "$WRANGLER_CONFIG" 2>/dev/null; then
  echo "  [worker] D1 bindings detected, checking migrations..."
  if [ -d "migrations" ] && ls migrations/*.sql &>/dev/null 2>&1; then
    # Check that .sql files are non-empty
    EMPTY_MIGRATIONS=0
    for sql_file in migrations/*.sql; do
      if [ ! -s "$sql_file" ]; then
        echo "  [worker] ✗ Empty migration file: $sql_file"
        EMPTY_MIGRATIONS=$((EMPTY_MIGRATIONS + 1))
      fi
    done
    if [ "$EMPTY_MIGRATIONS" -eq 0 ]; then
      echo "  [worker] ✓ D1 migrations found and non-empty"
    else
      ERRORS=$((ERRORS + EMPTY_MIGRATIONS))
    fi
  else
    echo "  [worker] ✗ D1 bindings configured but no migrations/*.sql files found"
    ERRORS=$((ERRORS + 1))
  fi
fi

# --- 6. Durable Object class exports ---
if grep -q "durable_objects" "$WRANGLER_CONFIG" 2>/dev/null || grep -q '"durable_objects"' "$WRANGLER_CONFIG" 2>/dev/null; then
  echo "  [worker] Durable Objects bindings detected, checking class exports..."

  # Extract class names from wrangler config
  DO_CLASSES=""
  if [[ "$WRANGLER_CONFIG" == *.toml ]]; then
    DO_CLASSES=$(grep -oE 'class_name[[:space:]]*=[[:space:]]*"[^"]+"' "$WRANGLER_CONFIG" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/' || echo "")
  else
    DO_CLASSES=$(grep -oE '"class_name"[[:space:]]*:[[:space:]]*"[^"]+"' "$WRANGLER_CONFIG" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/' || echo "")
  fi

  if [ -n "$DO_CLASSES" ]; then
    for CLASS_NAME in $DO_CLASSES; do
      # Search for exported class in source files
      if grep -rq "export class $CLASS_NAME" src/ functions/ worker/ 2>/dev/null; then
        echo "  [worker] ✓ DO class exported: $CLASS_NAME"
      else
        echo "  [worker] ✗ DO class not found: export class $CLASS_NAME"
        ERRORS=$((ERRORS + 1))
      fi
    done
  fi
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "  [worker] $ERRORS check(s) failed"
  exit 1
fi

echo "  [worker] All Cloudflare checks passed"
exit 0
