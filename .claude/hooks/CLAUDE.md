# hooks/

Claude Code event hooks. These run automatically at various lifecycle points.

## Files

| File | Hook Event | Role |
|------|------------|------|
| `lint-on-save.sh` | PostToolUse (Edit/Write) | Lint saved files, dispatch to engine-specific linter |
| `lint-session-stop.sh` | SessionEnd | Full lint sweep report at end of session |
| `pre-compact-context.sh` | PreCompact | Capture branch/PR state before context compaction |
| `session-start.sh` | SessionStart | Configure git hooks, run engine-specific init |
| `stop-uncommitted-check.sh` | Stop | Warn about uncommitted code files |
| `subagent-quality-gate.sh` | SubagentStop | Verify subagent pushed and created PR |
| `worktree-setup.sh` | WorktreeCreate | Auto-setup new worktrees (delegates to engine hook) |

## Engine Hooks

After `setup-engine.sh` runs, engine-specific hooks are copied here:
- `lint-on-save-engine.sh` -- engine-specific file linting
- `pre-commit-engine.sh` -- engine-specific pre-commit checks
- `worktree-setup-engine.sh` -- engine-specific worktree seeding
