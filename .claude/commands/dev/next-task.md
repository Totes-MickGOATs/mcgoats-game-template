---
description: Pick up the next task from the project backlog
---

# Next Task

1. Check for urgent items first:
   ```bash
   gh issue list --label "ci-failure" --state open --limit 3
   gh issue list --label "bug" --state open --limit 3
   ```

2. Check the project status:
   - Read `.ai/knowledge/status/project-status.md`
   - Identify the current phase and incomplete items

3. Check for open issues:
   ```bash
   gh issue list --state open --limit 10
   ```

4. Pick the highest-priority task. Priority order:
   1. CI failures (blocking all merges)
   2. Bugs (affecting functionality)
   3. Current-phase incomplete items
   4. Enhancements

5. Create a feature branch and begin work.
