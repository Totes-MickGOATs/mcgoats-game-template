---
description: Review code changes on the current branch
---

# Code Review

Review the current branch's changes against the base branch.

## Checklist

1. **Diff overview:**
   ```bash
   git diff origin/main...HEAD --stat
   ```

2. **For each changed file, verify:**
   - [ ] No magic numbers (use named constants)
   - [ ] Type annotations on function signatures
   - [ ] Error handling at system boundaries
   - [ ] No hardcoded paths or credentials
   - [ ] DRY — no duplicated logic (extract at 3+ instances)
   - [ ] Tests exist for new/changed logic
   - [ ] CLAUDE.md updated if files added/removed

3. **Architecture check:**
   - [ ] Changes follow existing patterns in the codebase
   - [ ] No unnecessary coupling between systems
   - [ ] Signal/event names are consistent
   - [ ] Manifest updated if new system files added

4. **Report:** List any issues found with file:line references and suggested fixes.
