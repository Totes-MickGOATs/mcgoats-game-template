---
description: Run Unity tests (Edit Mode or Play Mode)
---

Run Unity Test Framework tests for this project.

## Steps

1. Check if Unity Editor is running (MCP read_console)
2. If a specific test file is provided, run just that test
3. Otherwise run all Edit Mode tests
4. Report results

## Commands

```bash
# Edit Mode tests (fast, no scene needed)
just test

# Play Mode tests (slower, needs scene)
just test-play

# Specific test by filter
just test-fast "TestClassName"
```

Check console for test results: use `read_console` MCP tool or check `test-results/*.xml`
