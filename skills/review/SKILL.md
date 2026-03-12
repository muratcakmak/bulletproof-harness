# Code Review

## Purpose
Perform a thorough code review of recent changes, checking for bugs, security issues, performance problems, and convention violations.

## Instructions
1. Run `git diff HEAD~1` (or `git diff main`) to see recent changes
2. Search memory for conventions: `harness/bin/search-memory.sh "convention"`
3. Search memory for known bugs: `harness/bin/search-memory.sh "bug"`
4. Review each changed file for:
   - **Bugs**: Logic errors, off-by-one, null pointer, race conditions
   - **Security**: SQL injection, XSS, secrets in code, improper auth checks
   - **Performance**: N+1 queries, unnecessary re-renders, missing caching
   - **Types**: Any `any` usage, missing type annotations, incorrect types
   - **Conventions**: Violations of memory/conventions.md
   - **Error handling**: Missing try/catch, swallowed errors, unhelpful messages
5. For each issue found, note:
   - Severity: critical / warning / nit
   - File + line
   - What's wrong
   - Suggested fix
6. Log findings: `harness/bin/update-memory.sh bugs "Found X in review"`

## Output
- List of issues with severity, location, and suggested fixes
- No code changes (review only — unless --fix flag is passed)
- Bugs logged to memory/bugs.md
