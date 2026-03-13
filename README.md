# mcgoats-game-template

[![Validate Template](https://github.com/Totes-MickGOATs/mcgoats-game-template/actions/workflows/validate-template.yml/badge.svg)](https://github.com/Totes-MickGOATs/mcgoats-game-template/actions/workflows/validate-template.yml)

AI-powered game development template with battle-tested CI/CD, auto-merge queues, TDD enforcement, and Claude Code integration. Start new game projects with production-grade infrastructure from day one.

## What You Get

- **3-layer main branch protection** — Claude Code PreToolUse hook + git pre-commit hook + GitHub branch protection
- **Auto-merge queue** — FIFO squash-merge triggered by `ready-to-merge` label
- **CI pipeline** — Common lint + engine-specific checks as reusable workflows
- **Post-merge safety net** — Full test suite runs after merge, auto-creates issues on failure
- **Claude Code integration** — Hooks, commands, statusline, subagent quality gates
- **TDD enforcement** — Red-Green-Commit workflow baked into project conventions
- **Worktree-based branching** — Isolated feature branches with import cache seeding
- **System manifests** — Track which files belong to which game system
- **CLAUDE.md hierarchy** — Per-directory documentation that AI agents read automatically
- **Skills library** — 5 engine-agnostic skills + engine-specific skills loaded on demand
- **Python tooling** — uv-managed scripts for validation, coverage, and docs freshness

## Engine Support

| Engine | Status | CI | Skills |
|--------|--------|-----|--------|
| **Godot 4.x** | Production-ready | GDScript lint, parse check, GUT tests, registry validation | 10+ Godot skills |
| **Unity** | Basic stubs | C# compilation check | MCP config (UnityMCP + coplay-mcp) |
| **Unreal** | Empty stubs | Placeholder | — |

Godot support is battle-tested across a shipping game project. Unity and Unreal modules are starting points — contributions welcome.

## Quick Start

### 1. Create your project

Click **"Use this template"** on GitHub, or:

```bash
gh repo create my-org/my-game --template Totes-MickGOATs/mcgoats-game-template --public
git clone https://github.com/my-org/my-game.git
cd my-game
```

### 2. Choose your engine

```bash
./tools/setup-engine.sh godot   # or: unity, unreal
```

This copies engine-specific configs, CI workflows, hooks, skills, and lint configs into the right places, then removes the `engine/` directory.

### 3. Configure GitHub

1. **Branch protection** on `main`:
   - Require PR before merging
   - Require status checks: `Lint & Preflight` (add engine-specific checks too)
   - No force push, no deletion
2. **Repository secret** `MERGE_TOKEN`: a PAT with `repo` + `workflow` scopes (for auto-merge)
3. **Enable auto-merge** in repo settings

### 4. Start building

```bash
just worktree-create my-feature   # Create feature branch + worktree
# ... develop with TDD ...
just ship                         # Push + create PR + watch CI
```

## Syncing Template Updates

Games created from this template are independent repos. To pull in template improvements:

```bash
# One-time: add template as remote
git remote add template https://github.com/Totes-MickGOATs/mcgoats-game-template.git

# Pull updates
git fetch template
git merge template/main --no-ff

# Check for drift
just check-template-sync
```

## Project Structure

```
├── CLAUDE.md                     # AI workflow rules (engine-agnostic)
├── justfile                      # Task runner (imports justfile.engine)
├── .github/workflows/            # CI: auto-merge, lint, post-merge tests
├── .githooks/                    # Pre-commit (main branch guard), pre-push, commit-msg
├── .claude/                      # Claude Code hooks, commands, settings
├── .agents/skills/               # AI agent skills library
├── .ai/knowledge/                # Architecture docs, plans, status
├── scripts/tools/                # Python validation scripts
├── resources/manifests/          # System manifest files
├── tests/                        # Test directory with helpers
├── engine/                       # Engine modules (removed after setup)
│   ├── godot/                    # Godot 4.x configs, CI, skills
│   ├── unity/                    # Unity stubs
│   └── unreal/                   # Unreal stubs
└── tools/
    └── setup-engine.sh           # Engine selector script
```

## Requirements

- **Python 3.14+** with [uv](https://docs.astral.sh/uv/)
- **just** task runner (`cargo install just` or via package manager)
- **gh** CLI (GitHub CLI)
- **Claude Code** CLI (for AI agent features)
- Engine-specific: Godot 4.x / Unity 2022+ / Unreal 5.x

## License

MIT — see [LICENSE](LICENSE).

Built by [McGOATs Games](https://github.com/Totes-MickGOATs).
