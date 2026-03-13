# Deploy Check

## Purpose
Pre-deployment verification checklist for Cloudflare projects. Run this before deploying to catch common issues with Pages, Functions, D1, and Durable Objects.

## Instructions
1. Run full build: verify compilation passes
2. Run all tests: verify test suite passes
3. Run `wrangler types`: verify env type generation succeeds
4. Check for secrets in code: grep for API keys, tokens, passwords
5. Check environment files: verify .dev.vars exists with all required vars
6. Check Cloudflare/Wrangler config:
   - Verify wrangler CLI is installed
   - Verify D1 migrations exist and are non-empty (if D1 bindings configured)
   - Verify Durable Objects class exports match config (if DO bindings configured)
   - Verify .dev.vars exists for local secrets
   - Run `wrangler deploy --dry-run` validation
7. Check for debug code: console.log, debugger statements, TODO comments
8. Report results as a checklist

## Output
- Pre-deploy checklist with pass/fail for each item
- Any blocking issues that must be fixed before deploy
- Warnings for non-blocking issues
