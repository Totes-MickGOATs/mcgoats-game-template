---
description: Set up a new project from this template — interactive guided walkthrough
---

# Project Setup

Welcome! This command will walk you through setting up your new game project.

Run the full interactive setup:

$ARGUMENTS

If no arguments are provided, run `/dev:init-project` which handles all 7 phases:

1. **Prerequisites** — verify git, gh, uv, just are installed
2. **Engine Selection** — choose Godot, Unity, or Unreal
3. **GitHub Configuration** — branch protection, MERGE_TOKEN secret, auto-merge
4. **Local Setup** — git hooks, Python dependencies
5. **Project Identity** — customize README, CLAUDE.md, config files
6. **Verification** — test the full branch workflow end-to-end
7. **Next Steps** — what to build first

If the user provides an engine name as an argument (e.g., `/setup godot`), skip the engine selection prompt and use that engine directly.

After setup is complete, remind the user:
- Type `/dev:next-task` to see what to work on first
- All code changes go through feature branches — just describe what you want to build
- Claude handles branching, commits, PRs, and CI automatically
