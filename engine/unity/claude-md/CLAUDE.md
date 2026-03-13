# engine/unity/claude-md/

CLAUDE.md templates for Unity projects. These are copied into the project directory structure by `setup-engine.sh` during engine initialization.

## Templates

| File | Destination | Purpose |
|------|-------------|---------|
| `assets-scripts-CLAUDE.md` | `Assets/Scripts/CLAUDE.md` | C# script conventions, namespaces, assembly definitions |
| `assets-scenes-CLAUDE.md` | `Assets/Scenes/CLAUDE.md` | Scene management conventions, prefab-first patterns |
| `tests-CLAUDE.md` | `tests/CLAUDE.md` | Unity Test Framework structure, TDD conventions, naming |

## How Templates Are Used

During `setup-engine.sh`, each template is copied to its destination path. The templates provide Claude Code with context about Unity-specific conventions when working in those directories.

Templates reference skill files in `.agents/skills/` — these skills are loaded on demand when Claude needs deeper context about a particular system.
