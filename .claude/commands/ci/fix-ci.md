---
description: Fix a failing CI check on the current branch
---

# Fix CI Failure

## Steps

1. **Identify the failure:**
   ```bash
   gh run list --branch $(git branch --show-current) --limit 5
   ```
   Then view the failed run:
   ```bash
   gh run view <run-id> --log-failed
   ```

2. **Diagnose:** Read the error output carefully. Common causes:
   - Lint failures (formatting, style)
   - Test failures (logic errors, missing mocks)
   - Registry validation failures (missing manifest entries)
   - CLAUDE.md freshness (docs not updated with code)

3. **Fix:** Make the minimum change to fix the issue. Do not refactor unrelated code.

4. **Verify locally:**
   - Lint: `just python-lint` (Python files)
   - Registry: `just validate-registry`
   - Docs: Run `/dev:validate-docs`
   <!-- ENGINE-SPECIFIC: Engine lint commands added by setup-engine.sh -->

5. **Push the fix:**
   ```bash
   git add <fixed-files>
   git commit -m "fix: resolve CI failure — <brief description>"
   git push
   ```

6. **Confirm CI passes:**
   ```bash
   gh run watch
   ```
