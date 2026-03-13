<!-- Copied to .claude/commands/editor/ by tools/setup-engine.sh when Godot is selected -->
Check the health of the Godot editor setup and all project tooling.

1. **MCP Connection:**
   - Try `mcp__godot-mcp__get_godot_version` — if it fails, the editor isn't running or MCP addon isn't loaded
   - If connection fails, suggest: "Open the Godot editor and ensure the godot_mcp addon is enabled in Project Settings > Plugins"

2. **Addon Integrity:**
   - Check that expected addon directories exist under `addons/`
   - If the project uses native plugins (GDExtension), run `just check-dlls` to verify DLLs are real binaries (not LFS pointer stubs)
   - If DLLs are stubs, suggest: `git lfs pull`

3. **Tooling:**
   - Check `gdformat --version` is available
   - Check `gdlint --version` is available
   - Check `uv --version` is available
   - Check `gh --version` is available (for CI commands)
   - Check `git lfs version` is available

4. **Git Hooks:**
   - Verify `.githooks/pre-commit` exists and is executable
   - Check `git config core.hooksPath` is set to `.githooks`
   - If not configured, suggest: `just setup`

5. **Python Environment:**
   - Check `.venv/` exists
   - Run `uv sync --dry-run` to verify dependencies are up to date

6. **Report:**
   ```
   Editor Health Check
   ===================
   MCP Connection:  OK / FAILED (reason)
   Addons:          OK / MISSING: [list]
   DLL Integrity:   OK / STUBS: [list] / N/A (no native plugins)
   gdformat:        OK (version) / MISSING
   gdlint:          OK (version) / MISSING
   uv:              OK (version) / MISSING
   gh CLI:          OK (version) / MISSING
   Git LFS:         OK (version) / MISSING
   Git Hooks:       OK / NOT CONFIGURED
   Python Env:      OK / NEEDS SYNC
   ```

7. **Auto-fix** any issues that have simple solutions (run `just setup`, `git lfs pull`, `uv sync`). Ask before taking action.
