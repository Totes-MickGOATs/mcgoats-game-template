# engine/godot/

Godot engine module. Copied to project root by `tools/setup-engine.sh`, then `engine/` is removed.

## Files

| File | Role |
|------|------|
| `SETUP.md` | Godot-specific setup instructions |
| `.mcp.json` | MCP server config (godot-mcp bridge) |
| `justfile.engine` | Godot-specific just recipes (test-fast, seed-import, lint) |
| `gdlintrc` | GDScript lint config |
| `gdformatrc` | GDScript format config |
| `.gitignore.append` | Godot ignore patterns appended to root .gitignore |

## Subdirectories

| Dir | Contents |
|-----|----------|
| `ci/` | CI workflow for GDScript linting |
| `hooks/` | Pre-commit, lint-on-save, worktree-setup hooks |
| `commands/` | Editor slash commands |
| `claude-md/` | CLAUDE.md templates for common Godot directories |
| `skills/` | 47 Godot-specific skills |
