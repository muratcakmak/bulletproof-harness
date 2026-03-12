# Deploy Check

## Purpose
Pre-deployment verification checklist. Run this before deploying to catch common issues.

## Instructions
1. Run full build: verify compilation passes
2. Run all tests: verify test suite passes
3. Check for secrets in code: grep for API keys, tokens, passwords
4. Check .env.example: verify all required env vars are documented
5. Check Docker build (if Dockerfile exists): verify it builds successfully
6. Check for debug code: console.log, debugger statements, TODO comments
7. Check package versions: look for known vulnerabilities
8. Verify health check endpoint responds (if API)
9. Report results as a checklist

## Output
- Pre-deploy checklist with pass/fail for each item
- Any blocking issues that must be fixed before deploy
- Warnings for non-blocking issues
