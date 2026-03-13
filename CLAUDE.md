# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## BEFORE YOU WRITE ANY CODE — Read This First

> **MANDATORY PREREQUISITE:** You must be on a feature branch before writing, editing, or creating any file.
>
> **If you are a subagent spawned with `isolation: "worktree"`:** You are already on a feature branch. Verify with `git branch --show-current` — it should show `feat/...` or `.claude/...`. Proceed to implementation.
>
> **If you are the main agent or were NOT spawned with `isolation: "worktree"`:**
> 1. **Do NOT edit any files yet.** You are on `main` and commits will be blocked.
> 2. **Dispatch a subagent with `isolation: "worktree"`** to do the implementation work.
> 3. The subagent handles: code changes → commit → push → PR → CI green → label `ready-to-merge`.
> 4. You verify the PR merged successfully, then run `just worktree-cleanup <task>`.
>
> **Why this matters:** Three enforcement layers block main branch commits (PreToolUse hook, git pre-commit hook, GitHub branch protection). If you edit files on main, you'll waste work that can't be committed.
>
> **Full workflow guide:** `.agents/skills/branch-workflow/SKILL.md`

---

## First-Time Setup

If this is a fresh clone or a new project created from the template, see **`SETUP.md`** for:
- Required tool installation (git, gh, uv, just)
- Engine selection and configuration (`tools/setup-engine.sh`)
- GitHub repository protection rules and secrets
- Git hooks setup
- Or run `/dev:init-project` for an interactive guided walkthrough.

---

## Project Overview

<!-- ENGINE-SPECIFIC: Project description added by setup-engine.sh -->

**Game:** _Your game name here_ — _brief description_.

Current state: _Update `.ai/knowledge/status/project-status.md` with phase tracking._

<!-- ENGINE-SPECIFIC: Engine version, executable path, launch commands added by setup-engine.sh -->

## Git — Branch Workflow (STOP AND READ)

> **MANDATORY:** All changes go through feature branches + PRs. Direct commits/pushes to main are **blocked** by local hooks AND GitHub branch protection. You WILL get errors if you try.
>
> **Before writing ANY code**, read the workflow below. Full details + gotchas: `.agents/skills/branch-workflow/SKILL.md`

### Quick Reference

```
just worktree-create <task>          # 1. Create feature branch + worktree
# ... develop, commit, test ...      # 2. Work on feat/<task> branch
git push -u origin feat/<task>       # 3. Push
gh pr create --base main             # 4. Open PR → CI runs automatically
# CI auto-labels ready-to-merge      # 5. Auto-merge triggers on label → squash-merges
just worktree-cleanup <task>         # 6. Clean up after merge
```

### Branch Workflow

1. **Create a worktree:** `just worktree-create <task-name>` (creates `feat/<task>` from `origin/main`)
2. **Develop:** Commit frequently in the feature branch. Commit message format: `type: short description`
3. **Push + PR:** `git push -u origin feat/<task>` then `gh pr create --base main`
4. **CI validates:** Lint & Preflight must pass (tests are advisory unless configured otherwise)
5. **Merge:** CI auto-adds `ready-to-merge` label → auto-merge workflow squash-merges when up-to-date
6. **Cleanup:** `just worktree-cleanup <task>` or `just worktree-sync` for batch cleanup

### Agent Protocol (Claude Code agents with `isolation: "worktree"`)

> **HARD RULES FOR AGENTS:**
> - **NEVER commit on the `main` branch.** A PreToolUse hook will block you. Work on your feature branch.
> - **NEVER use `--no-verify`** on git commit. The hook will block this too. Fix the underlying issue instead.
> - **ALWAYS use `isolation: "worktree"`** when spawning subagents that write code.
> - **NEVER leave your branch unmerged or CI failing.** You own your branch from creation to merge. See Definition of Done below.

Agents follow the same workflow: develop in worktree → push → PR → label `ready-to-merge` → auto-merge serializes. The worktree is created automatically by Claude Code — start at step 2.

### Dispatching Subagents (Main Agent Responsibility)

When you receive a task that requires code changes:

1. **Do NOT start editing files.** You are likely on `main`.
2. **Dispatch a subagent** with `isolation: "worktree"` to handle implementation.
3. **The subagent is responsible for the full lifecycle:** code → test → commit → push → PR → CI green → `ready-to-merge` label.
4. **After the subagent completes**, verify the PR was created and CI is green.
5. **Cleanup:** `just worktree-cleanup <task>` once the PR merges.

**Common mistake:** Starting to edit files directly, then discovering you can't commit because you're on main. Always dispatch first, edit never.

### Keeping Branches Fresh

**Main agent (on main):** Before dispatching subagents, pull the latest remote main so worktrees start from the newest commit:

```bash
git fetch origin && git pull --ff-only origin main
```

**Subagents (on feature branches):** Before pushing, rebase onto the latest main to incorporate changes that landed while you were working:

```bash
git fetch origin && git rebase origin/main
```

If rebase conflicts occur, resolve them before pushing. Do not push a branch that is behind `origin/main` when commits have landed since your worktree was created.

### Definition of Done

A task is **not done** until ALL of these are true:

1. **PR is open** with all commits pushed
2. **Lint CI is green** — `Lint & Preflight` passes on GitHub Actions
3. **Auto-merge is enabled** — `gh pr merge --auto --squash` or `ready-to-merge` label applied
4. **Local tests pass** — run relevant test files for your changes before pushing
5. **Bulletproof quality checklist passed** — see `/dev:bulletproof` for the full process (Phases 0-5)

**You do NOT need to wait for merge.** Once lint CI is green and auto-merge is enabled, your task is done. The merge queue handles the rest. Move on to the next task.

If lint CI fails after you push, you are responsible for:
- Checking the CI output: `gh run view --log-failed` or `gh run view <run-id> --log`
- Diagnosing and fixing the failure in your feature branch
- Pushing the fix and confirming lint CI goes green

### Commit Rules

- Commit every file immediately after creating or updating/editing/writing to it, even if it's just a stub.
- Never leave uncommitted changes at the end of a task.
- Commit message format: `type: short description` (e.g., `feat: add surface friction zone`, `fix: correct wheel radius`).
- Conventional commit types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`, `style`, `build`

### Master Protection (Three Layers)

- **Local hooks:** `.githooks/pre-commit` blocks commits on main, `.githooks/pre-push` blocks pushes to main
- **Claude hooks:** `.claude/hooks/` PreToolUse hooks block file edits on main
- **GitHub branch protection:** Required PR, required CI checks, no force push, no deletion
- **Bypass (release only):** `ALLOW_MASTER_COMMIT=1` / `ALLOW_MASTER_PUSH=1` environment variables

## Testing (TDD)

> **MANDATORY:** Write tests FIRST, run them, then implement. Tests MUST be executed — never claim "fixed" or "verified" without running tests. No exceptions.

<!-- ENGINE-SPECIFIC: Test framework, test directory layout, and runner commands added by setup-engine.sh -->

### TDD Cycle (Red-Green-Commit)

Every bug fix or feature MUST follow this exact cycle. No steps may be skipped.

1. **Hypothesize** — Identify the potential cause of the issue or the behavior to implement
2. **Write a failing test** — Write a test that confirms your hypothesis (demonstrates the bug or specifies the desired behavior)
3. **Run the test → confirm RED** — Execute the test and verify it fails for the expected reason. If it passes, your hypothesis is wrong — revise it
4. **Implement the fix/feature** — Write the minimum code to make the test pass
5. **Run the test → confirm GREEN** — Execute the test and verify it now passes. If it still fails, iterate on the implementation
6. **Commit** — Tests and implementation together (or tests first if independent)

> **CRITICAL:** Steps 3 and 5 are non-negotiable. A test that was never run proves nothing. An implementation that was never verified against a test is not done. Agents that skip test execution are violating this project's core development practice.

### Test Tiers — Unit AND Integration

Most changes require BOTH unit tests and integration tests:

| Tier | What it tests | When required | Example |
|------|--------------|---------------|---------|
| **Unit** | Single function/class in isolation, mocked dependencies | Always | Tests math helpers with mock inputs |
| **Integration** | Multiple systems working together at runtime | When the change involves wiring, signals, or cross-system interaction | Tests that scene correctly wires systems together |
| **E2E** | Full game running, real scene tree | Complex gameplay flows (lower priority, not required for every change) | Boot-to-gameplay flow |

- **Unit tests** verify the logic is correct in isolation
- **Integration tests** verify the wiring is correct at runtime — signals connected, nodes found, systems interacting properly
- A unit test passing does NOT mean the feature works in-game. If the change involves system wiring, write an integration test too
- When in doubt, write both. It is better to over-test than to ship a "tested" feature that breaks at runtime

### Testing Strategy: Local TDD, Post-Merge Safety Net

> **IMPORTANT:** Run tests locally during TDD. The full suite runs automatically post-merge on main.

**Do NOT run the full test suite locally.** It ties up the developer's machine. Instead:

1. Write your test, run it locally for the red-green TDD cycle
2. Push to your feature branch — lint CI runs automatically
3. Once lint passes, auto-merge handles the rest
4. Full test suite runs post-merge on main
5. If post-merge tests fail, a `ci-failure` issue is auto-created — run `/ci:next-fix` to pick it up

## Python Tooling (scripts/tools only, not game code)

- **Python 3.14** with **uv** as the package manager
- Virtual environment at `.venv/` (managed by uv)

```bash
uv sync                          # Install dependencies
uv add <package>                 # Add a dependency
uv run python <script.py>        # Run a script
```

## Architecture

<!-- ENGINE-SPECIFIC: Autoloads/singletons, scene structure, key scripts added by setup-engine.sh -->

### Conventions

<!-- ENGINE-SPECIFIC: Engine-specific conventions (coordinate system, physics, etc.) added by setup-engine.sh -->

- **Signal Up, Call Down** — global systems emit signals, children call methods on parents
- **No magic numbers** — use named constants for layer IDs, type enumerations, algorithm parameters
- **Type annotations** — always annotate function signatures and return types

## Value Mutability Tiers

When deciding how to declare a value, use the appropriate tier:

| Tier | Mechanism | When to Use | Example |
|------|-----------|-------------|---------|
| **Const** | Language constant / `static readonly` | Algorithm logic, physics math, layer IDs, enum values — never changes at runtime | Layer bitmasks, string identifiers |
| **Export** | Inspector-editable field | Per-instance tuning set in the editor — varies between scenes/nodes but fixed at runtime | Spring stiffness, difficulty tier |
| **Settings** | Settings manager / config file | User preferences persisted to disk — changed via Options menu | Graphics quality, audio volumes, input bindings |
| **Dynamic** | Runtime variable | Computed or changed every frame/event — driven by gameplay | Current speed, input vectors, health points |

- **Central constant classes** for collision layers, surface types, or other domain enumerations
- **Never use bare numeric literals** for values that have a named constant

## DRY / Declarative Coding Patterns

> **MANDATORY:** Prefer declarative data structures over imperative boilerplate. When you see 3+ instances
> of the same pattern (UI creation, setup wiring, validation loops), extract a shared helper or use a
> data-driven approach.

### When to Extract

- **3+ instances** of the same creation/validation/setup pattern → extract a helper
- **200+ lines** of match/if arms for property routing → use a bridge/descriptor pattern
- **10+ signal connections** between two nodes → use a wiring table
- **5+ setup methods** in an orchestrator → consider a subsystem registry
- Adding a new item should require **1 data entry**, not touching UI/logic code

### Declarative Patterns

| Pattern | When to Use |
|---------|-------------|
| **Data Model → Renderer** | Complex UI driven by configuration (tuning panels, option menus) |
| **Property Bridge** | Multi-target property routing (replaces match/if chains) |
| **Signal Wiring Table** | Connecting 5+ signals between two nodes |
| **Subsystem Registry** | Orchestrators that init 5+ subsystems (editors, main scene) |
| **Validation Runner** | Test loops that check arrays of items against rules |
| **Extracted Processors** | Pipeline steps that can be unit-tested independently |

## System Registry

> **MANDATORY:** Every game system must have a manifest in `resources/manifests/`.
> When adding files to a system, add them to that system's manifest. When creating a new system, create a manifest.
> When deprecating a system, set `status = DEPRECATED` and fill in `replaced_by`.

- **Manifests:** `resources/manifests/` — one per system, declares owned files, status, dependencies
- **Validation:** `just validate-registry` (CI) or runs on debug boot
- **Statuses:** ACTIVE (in use), DEPRECATED (replaced, do not modify), EXPERIMENTAL (WIP, not integrated)

## Documentation Self-Improvement

> **MANDATORY:** When editing or fixing code in any directory, review the local `CLAUDE.md` file.
> If the documentation is outdated, inaccurate, or missing information about the change you just made,
> update the `CLAUDE.md` in the same commit or a follow-up commit. This keeps documentation evergreen.

- Every non-hidden directory has a `CLAUDE.md` describing its contents and linking relevant skills
- Each `CLAUDE.md` has a "Relevant Skills" section pointing to `.agents/skills/` for lazy-loaded context
- When adding a new file to a directory, add it to that directory's `CLAUDE.md` file listing
- When removing a file, remove it from the listing (do not leave "removed" comments)
- When adding a new directory, create a `CLAUDE.md` for it with skill references
- Skill files live in `.agents/skills/<name>/SKILL.md` — reference them, don't duplicate their content

## Key Reference Files

- `.agents/skills/branch-workflow/SKILL.md` — **Branch workflow, merge queue, worktree recipes, gotchas (READ FIRST)**
- `.ai/knowledge/architecture/system-overview.md` — scene graph, signal map, data flow, ADRs
- `.ai/knowledge/architecture/coding-standards.md` — coding conventions for this project
- `.ai/knowledge/status/project-status.md` — phase checklist, full scripts/scenes inventory
- `VERSIONING.md` — SemVer convention, release lifecycle, build types
- `SETUP.md` — first-time project setup guide

<!-- ENGINE-SPECIFIC: Engine-specific skill references added by setup-engine.sh -->
