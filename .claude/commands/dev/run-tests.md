---
description: Run tests for the current changes
---

# Run Tests

1. Identify changed files:
   ```bash
   git diff origin/main...HEAD --name-only
   ```

2. Find corresponding test files for each changed source file.

3. Run the relevant tests:
   <!-- ENGINE-SPECIFIC: Test runner command added by setup-engine.sh -->
   ```bash
   echo "No engine configured. Run setup-engine.sh first."
   ```

4. If tests fail:
   - Read the failure output
   - Fix the issue
   - Re-run to confirm green
   - Commit the fix

5. If no tests exist for changed code, write them (TDD: red → green → commit).
