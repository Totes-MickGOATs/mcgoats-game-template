# engine/unity/commands/

Unity-specific Claude Code slash commands. These are copied into `.claude/commands/` by `setup-engine.sh`.

## Commands

| Command | File | Description |
|---------|------|-------------|
| `/dev:run-tests-unity` | `dev/run-tests-unity.md` | Run Unity Test Framework tests (Edit Mode or Play Mode) |
| `/editor:compile-check` | `editor/compile-check.md` | Check for C# compilation errors via CLI or MCP console |

## How Commands Work

Claude Code slash commands are markdown files in `.claude/commands/`. Each file has a YAML front matter with a `description` field and markdown body with instructions for the agent.

During engine setup, these command files are copied from `engine/unity/commands/` into the project's `.claude/commands/` directory, making them available as slash commands.
