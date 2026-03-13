---
description: Validate CLAUDE.md files are fresh and accurate
---

# Validate Documentation

1. Run the validation script:
   ```bash
   uv run python scripts/tools/validate_claude_md.py
   ```

2. For each flagged directory:
   - Read the CLAUDE.md
   - Compare against actual directory contents (`ls`)
   - Update file listings, add missing files, remove deleted files
   - Verify skill references are accurate

3. Check that every non-hidden directory has a CLAUDE.md file.

4. Commit documentation fixes:
   ```bash
   git add "**/CLAUDE.md"
   git commit -m "docs: update CLAUDE.md freshness"
   ```
