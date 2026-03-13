---
description: Pick up the next ci-failure issue and fix it
---

# Next CI Fix

1. Find open ci-failure issues:
   ```bash
   gh issue list --label "ci-failure" --state open --limit 5
   ```

2. If none found, check if there are any recent failures:
   ```bash
   gh run list --status failure --limit 5
   ```

3. Pick the oldest open issue. Read its body for the failure details.

4. Create a feature branch and fix the issue following `/ci:fix-ci` workflow.

5. Reference the issue in your PR: `Fixes #<issue-number>`

6. After PR merges, verify the issue was auto-closed.
