<!-- Copied to .claude/commands/editor/ by tools/setup-engine.sh when Godot is selected -->
Get comprehensive project status and health information. Gather and present:

1. **Project Metadata:**
   - Run `mcp__godot-mcp__get_project_info` for Godot project details
   - Run `mcp__godot-mcp__get_godot_version` for engine version

2. **Git Status:**
   - Run `git status --short` for working tree state
   - Run `git log --oneline -5` for recent commits
   - Run `git branch --show-current` for current branch
   - Note any uncommitted changes

3. **Code Health:**
   - Run `just format-check` to verify formatting
   - Report any lint issues found

4. **IDE Diagnostics:**
   - Check `mcp__ide__getDiagnostics` for any editor warnings/errors

5. **Addon Status:**
   - Check that expected addon directories exist under `addons/`
   - If the project uses native plugins, run `just check-dlls` to verify DLL integrity

6. **Test Status:**
   - Report number of test files in `tests/`
   - Note when tests were last run (from git log of test files)

7. **Present a dashboard:**
   ```
   Project Status
   ==============
   Engine:     Godot X.Y.Z
   Branch:     main (clean / N uncommitted)
   Last commit: abc1234 feat: description
   Format:     OK / N issues
   Addons:     N/N present
   Tests:      N files
   ```
