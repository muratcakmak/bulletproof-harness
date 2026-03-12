# Refactor

## Purpose
Analyze and refactor code for better readability, performance, and maintainability.

## Instructions
1. Read the target file(s) completely
2. Search memory for conventions: `harness/bin/search-memory.sh "convention"`
3. Identify issues:
   - Functions > 50 lines → split
   - Duplicated logic → extract shared utility
   - Unclear naming → rename for clarity
   - Missing error handling → add try/catch with proper errors
   - Any patterns that violate memory/conventions.md
4. Refactor incrementally — one change at a time, test between each
5. Run type-check after every change
6. Update memory/conventions.md if you establish a new pattern
7. Log what you changed: `harness/bin/update-memory.sh log "Refactored X because Y"`

## Output
- Cleaner code that follows project conventions
- No behavior changes (unless bugs were found)
- Updated memory with any new patterns discovered
