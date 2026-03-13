---
description: Initialize a new project from this template — guides you and the user through complete setup
---

# Initialize New Project

You are helping the user set up a brand new game project created from the mcgoats-game-template.
Walk them through each step interactively, confirming completion before moving on.

## Phase 1: Prerequisites

Check that required tools are installed. For each one, verify and report status:

1. **git** — `git --version` (need 2.x+)
2. **gh** — `gh auth status` (must be authenticated)
3. **uv** — `uv --version` (Python package manager)
4. **just** — `just --version` (command runner)

If any are missing, provide install instructions:
- git: https://git-scm.com/ or `winget install Git.Git`
- gh: `winget install GitHub.cli` or https://cli.github.com/
- uv: `curl -LsSf https://astral.sh/uv/install.sh | sh` or `winget install astral-sh.uv`
- just: `cargo install just` or `winget install Casey.Just`

## Phase 2: Engine Selection

Ask the user which game engine they're using:
- **Godot** (GDScript) — fully supported with CI, linting, testing, skills
- **Unity** (C#) — basic CI stubs, MCP integration
- **Unreal** (C++) — empty stubs, placeholder CI

Run the setup script:
```bash
bash tools/setup-engine.sh <engine>
```

Verify it completed successfully by checking:
- `.mcp.json` exists at root
- `justfile.engine` exists at root
- `engine/` directory is gone
- `.github/template-config.json` has the correct ENGINE value

## Phase 3: GitHub Configuration

### Branch Protection
Guide the user to set up branch protection on their default branch:

```bash
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Lint & Preflight"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null
}
EOF
```

**Important:** Tell the user this ensures no direct pushes to main. All changes go through PRs.

### MERGE_TOKEN Secret
This is CRITICAL for the auto-merge queue:

1. Go to https://github.com/settings/tokens and click "Generate new token (classic)"
2. Name: `MERGE_TOKEN for <repo-name>`
3. Scopes: `repo` (full) + `workflow`
4. Copy the token
5. Set it as a repo secret:
   ```bash
   gh secret set MERGE_TOKEN
   ```
   (Paste the token when prompted)

**Why:** GitHub Actions workflows triggered by GITHUB_TOKEN cannot trigger other workflows.
The auto-merge queue needs MERGE_TOKEN to trigger CI on the merge commit.

### Enable GitHub Actions
Verify Actions is enabled:
```bash
gh api repos/{owner}/{repo}/actions/permissions
```

If disabled, the user needs to enable it in the repo Settings > Actions > General.

## Phase 4: Local Setup

```bash
# Install Python dependencies
uv sync

# Configure git hooks path
git config core.hooksPath .githooks

# Ensure hooks are executable
chmod +x .githooks/* .claude/hooks/* .claude/*.sh

# Verify hooks are active
git config core.hooksPath
# Should output: .githooks
```

Test the main branch protection hook:
```bash
# This SHOULD fail with "Direct commit to main blocked"
echo "test" > /tmp/test-hook.txt
git add /tmp/test-hook.txt 2>/dev/null || true
git commit -m "test: hook check" 2>&1 || echo "Hook correctly blocked commit on main"
git reset HEAD /tmp/test-hook.txt 2>/dev/null || true
```

## Phase 5: Project Identity

Guide the user to customize these files:

1. **README.md** — Replace template text with game name, description, features
2. **`.github/template-config.json`** — Set `GAME_NAME` to the actual game name
3. **`.ai/knowledge/status/project-status.md`** — Initialize phase tracking for the project
4. **`.ai/knowledge/architecture/coding-standards.md`** — Add project-specific conventions
5. **`cliff.toml`** — In `postprocessors`, replace `https://github.com/YOUR_ORG/YOUR_REPO` with the actual repo URL
6. **`CLAUDE.md`** — Fill in engine-specific sections, add project overview

## Phase 6: Verification

Run a full verification to confirm everything works:

```bash
# List available recipes (should show both base + engine recipes)
just --list

# Run Python lint (should pass on clean template)
just python-lint

# Validate the system registry (should pass with example manifest)
just validate-registry
```

Then test the full branch workflow end-to-end:

```bash
# Create a test branch
just worktree-create test-setup

# In the worktree: make a small change, commit, push
echo "# Test" >> README.md
git add README.md
git commit -m "test: verify template setup"
git push -u origin feat/test-setup

# Open a PR
gh pr create --base main --title "test: verify template setup" --body "Testing template workflow"

# Watch CI — should pass
just watch-ci

# Once green, clean up
just worktree-cleanup test-setup
```

If any step fails, check the Troubleshooting section below.

## Phase 7: Next Steps

Tell the user:
- Run `/dev:next-task` to see what to work on first
- Read `CLAUDE.md` for the complete workflow reference
- Read `.agents/skills/branch-workflow/SKILL.md` for detailed git workflow
- Start building: `just worktree-create first-feature`

## Troubleshooting

Common issues and solutions:

- **"Permission denied" on hooks** — Run `chmod +x .githooks/* .claude/hooks/* .claude/*.sh`
- **CI not triggering** — Check GitHub Actions is enabled in repo Settings > Actions > General
- **Auto-merge stuck** — Verify MERGE_TOKEN secret exists with correct scopes (`repo` + `workflow`)
- **`just` command not found** — Ensure it's in PATH, try opening a new terminal
- **`uv` command not found** — Install: `curl -LsSf https://astral.sh/uv/install.sh | sh` or `winget install astral-sh.uv`
- **Pre-commit blocks on main** — This is intentional! Use `just worktree-create <task>` to work on a feature branch
- **git hooks not running** — Run `git config core.hooksPath .githooks` to point git at the hooks directory
- **`jq` not found during engine setup** — Install jq: `winget install jqlang.jq` or `apt install jq`. The script has a sed fallback but jq is preferred.
- **Engine setup already ran** — If the `engine/` directory is gone, the script was already run. Check `template-config.json` for the configured engine.
