# Add Tests

## Purpose
Write comprehensive test coverage for existing code.

## Instructions
1. Identify the target module/component
2. Search memory for test conventions: `harness/bin/search-memory.sh "test"`
3. Check existing tests for patterns to follow
4. Write tests covering:
   - Happy path (normal usage)
   - Edge cases (empty inputs, nulls, boundary values)
   - Error cases (invalid inputs, network failures, timeouts)
   - Integration points (API calls, database queries)
5. Follow the project's test framework and conventions
6. Place test files according to conventions (co-located or in tests/ dir)
7. Run all tests: ensure existing tests still pass
8. Log what you tested: `harness/bin/update-memory.sh log "Added tests for X — Y% coverage"`

## Output
- New test files following project conventions
- All tests passing (new and existing)
- Coverage improvement logged to memory
