# First-Run Setup Checklist

After creating a project from this template, complete these steps.

## 1. Run Engine Setup

```bash
./tools/setup-engine.sh godot   # or: unity, unreal
```

This configures your project for a specific engine. See `engine/<engine>/SETUP.md` for engine-specific details.

## 2. Update Project Identity

Edit these files with your project's details:

- [ ] `CLAUDE.md` — Update "Project Overview" section with your game description
- [ ] `README.md` — Replace template description with your project's README
- [ ] `VERSIONING.md` — Review version convention, update if needed
- [ ] `cliff.toml` — In `postprocessors`, replace `https://github.com/YOUR_ORG/YOUR_REPO` with your actual repo URL
- [ ] `.github/template-config.json` — Set `GAME_NAME` and verify `ENGINE`

## 3. Configure GitHub Repository

- [ ] **Branch protection** on `main`:
  - Require pull request before merging
  - Required status checks: `Lint & Preflight` (+ engine-specific checks)
  - Block force pushes and branch deletion
- [ ] **Repository secret** `MERGE_TOKEN`:
  - Create a Personal Access Token with `repo` + `workflow` scopes
  - Add as repository secret named `MERGE_TOKEN`
- [ ] **Enable auto-merge** in repository Settings > General

## 4. Initialize Git Hooks

```bash
git config core.hooksPath .githooks
```

This enables the pre-commit main branch guard, pre-push protection, and commit message validation.

## 5. Install Python Dependencies

```bash
uv sync
```

## 6. Verify Everything Works

```bash
# Create a test feature branch
just worktree-create test-setup

# In the worktree, make a small change and commit
echo "# Test" >> TEST.md
git add TEST.md
git commit -m "test: verify setup"

# Push and create PR
git push -u origin feat/test-setup
gh pr create --base main --title "test: verify setup" --body "Testing template setup"

# Watch CI
just watch-ci

# Clean up after CI passes
gh pr close $(gh pr view --json number -q .number)
git push origin --delete feat/test-setup
just worktree-cleanup test-setup
```

## 7. Remove This File

Once setup is complete, delete `SETUP.md` and commit:

```bash
rm SETUP.md
git add -u
git commit -m "chore: remove setup checklist"
```

## Engine-Specific Setup

After running `setup-engine.sh`, check the engine's own setup guide:

- **Godot:** See notes in the generated CLAUDE.md about Godot version, physics engine, autoloads
- **Unity:** Configure UnityMCP and coplay-mcp servers in `.mcp.json`
- **Unreal:** Placeholder — contribute setup docs if you use this with Unreal
