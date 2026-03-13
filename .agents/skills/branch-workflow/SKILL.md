# Branch Workflow & Merge Queue Skill

How to correctly develop, commit, push, and merge code in this project. **Read this before writing any code.**

## The Golden Rule

**Never commit or push directly to main.** Local hooks and GitHub branch protection will block you. All work goes through feature branches and pull requests.

## Step-by-Step: Feature or Fix

### 1. Create an Isolated Worktree

```bash
just worktree-create <task-name>
# Fetches origin/main, fast-forwards local main, then creates
# feat/<task-name> branch from the latest remote main.
# Worktree lives at ../<project>-<task-name>/
cd ../<project>-<task-name>
```

This **always pulls the latest main from remote** before branching, so your feature branch starts from the true current state of main — not a stale local copy.

If you're a Claude Code agent launched with `isolation: "worktree"`, the worktree is already created for you — skip this step. Note that Claude Code's built-in worktree uses its own branching; if you need to guarantee you're on latest main, run `git fetch origin main && git rebase origin/main` inside the worktree.

### 2. Develop on the Feature Branch

- Commit frequently. Each file change gets its own commit (or a grouped commit if changes are atomic).
- Commit message format: `type: short description` (e.g., `feat: add surface friction zone`, `fix: correct wheel radius`).
- Follow TDD: write test first, run it red, implement, run it green, commit.

### 3. Push and Create a PR

```bash
git push -u origin feat/<task-name>
gh pr create --base main --title "feat: description" --body "..."
```

Or use the one-liner:

```bash
just pr "feat: description"    # push + create PR in one command
```

### 4. Wait for CI

Required checks must pass before the PR can merge:
- **Lint & Preflight** — format checks, lint, registry validation

If CI fails, fix the issue in the feature branch, push again. CI re-runs automatically.

### 5. Auto-Merge (Event-Driven)

CI automatically adds the `ready-to-merge` label when checks pass. The **auto-merge workflow** (`auto-merge.yml`) triggers immediately on label addition:
- If the PR is behind main, it rebases automatically, CI re-runs, label re-added on pass, merge re-triggered
- If CI is green and up-to-date, it squash-merges and deletes the remote branch
- If CI failed, it removes the label and comments on the PR

**No manual labeling needed in the normal flow.** CI handles it. If you need to manually re-add the label (e.g., after fixing a CI failure):

```bash
gh pr edit <number> --add-label "ready-to-merge"
```

**Safety net:** When new commits are pushed to a PR, the `pr-guard.yml` workflow immediately strips the `ready-to-merge` label before CI starts, ensuring the PR must pass CI again.

### 6. Cleanup

```bash
just worktree-cleanup <task-name>   # Remove worktree + local/remote branch
# OR
just worktree-sync                  # Batch: pull main, delete merged branches, prune
```

## Definition of Done

A task is **not done** until ALL of the following are true. Agents must self-monitor and self-correct until every item is satisfied.

| # | Criterion | How to Verify |
|---|-----------|---------------|
| 1 | PR is open with all commits pushed | `gh pr view` shows your PR |
| 2 | CI is green | `gh run list --branch <branch>` shows success |
| 3 | `ready-to-merge` label applied | `gh pr view` shows the label |
| 4 | No other agent's PR broken by your changes | Merge queue handles this — if it removes your label, you fix the conflict/failure |
| 5 | Knowledge synced | CLAUDE.md files, manifests updated if applicable |

### Owning Your CI

**You are responsible for your branch's CI from push to merge.** This means:

1. After every push, check CI status: `gh run list --branch feat/<task> --limit 3`
2. If CI fails, read the failure output: `gh run view <run-id> --log-failed`
3. Diagnose and fix the issue in your feature branch
4. Push the fix and wait for CI to go green
5. Only apply `ready-to-merge` after CI is green

**Do not:**
- Walk away from a red CI
- Assume "it works locally so CI must be wrong"
- Apply `ready-to-merge` before CI is green
- Leave your branch unmerged at the end of a task

### Self-Reflection on Failure

When CI fails or the merge queue rejects your PR:

1. **Read the actual error** — don't guess. Use `gh run view --log-failed`.
2. **Identify root cause** — is it your code, a flaky test, or a conflict with another PR?
3. **Fix and push** — don't just retry. Address the underlying issue.
4. **Update memory if needed** — if you discovered a new gotcha or pattern, record it so future agents don't hit the same issue.
5. **Re-apply the label** only after CI is green again.

## Enforcement Layers

This project has **three layers** preventing direct main commits:

| Layer | Mechanism | Bypassable? |
|-------|-----------|-------------|
| **Claude Code PreToolUse hook** | Blocks `git commit` on main and `--no-verify` usage | No — runs before the command, cannot be skipped |
| **Git pre-commit hook** | `.githooks/pre-commit` — checks branch name | Yes — `--no-verify` skips it (but layer 1 blocks that) |
| **GitHub branch protection** | Server-side — requires PR + CI checks | No — push to main is rejected server-side |

The PreToolUse hook is the primary guard for agents. Even if an agent tries `--no-verify`, the hook blocks it before git ever runs.

## Agent Protocol

### Subagents with `isolation: "worktree"`

When Claude Code spawns a subagent with `isolation: "worktree"`, the subagent gets its own worktree and feature branch automatically. The subagent is responsible for the full lifecycle:

1. **Verify branch**: `git branch --show-current` — should show a feature branch, not `main`
2. **Develop**: Write code, run tests, commit
3. **Push**: `git push -u origin <branch>`
4. **Create PR**: `gh pr create --base main`
5. **Monitor CI**: `gh run list --branch <branch>`
6. **Enable auto-merge**: `gh pr merge --auto --squash` or ensure `ready-to-merge` label is applied
7. **Do not wait for merge** — once CI is green and auto-merge is enabled, the task is done

### Main Agent Responsibilities

The main agent (on main) should:

1. **Never edit files directly** — dispatch subagents for code changes
2. **Pull latest main** before dispatching: `git fetch origin && git pull --ff-only origin main`
3. **Verify subagent work** — check the PR diff, not just CI status
4. **Cleanup after merge**: `just worktree-cleanup <task>`

### Hard Rules for All Agents

- **NEVER** commit on the `main` branch
- **NEVER** use `--no-verify` on git commit
- **NEVER** leave a branch unmerged or CI failing
- **ALWAYS** use `isolation: "worktree"` when spawning subagents that write code

## Gotchas & Common Mistakes

### "BLOCKED: Cannot commit on main branch"

The Claude Code PreToolUse hook detected a `git commit` while on the `main` branch. Switch to a feature branch.

### "BLOCKED: --no-verify is not allowed"

Never use `--no-verify`. It's blocked by the PreToolUse hook. Fix the root cause (lint errors, parse errors, etc.) instead of bypassing it.

### "ERROR: Direct commits to main are blocked"

You're on the `main` branch. You need to be on a feature branch.

```bash
# If you haven't started work yet:
just worktree-create my-task

# If you already made changes on main (uncommitted):
git stash
just worktree-create my-task
cd ../<project>-my-task
git stash pop
```

### "ERROR: Direct push to main is blocked"

Push your feature branch instead:

```bash
git push -u origin feat/<task-name>
```

### Branching From Stale Main

If you manually create a branch with `git checkout -b` instead of `just worktree-create`, your branch may be based on a stale local main. Always fetch first:

```bash
git fetch origin main
git checkout -b feat/my-task origin/main
```

`just worktree-create` handles this automatically.

### CI Fails After Rebase

The merge queue auto-rebases PRs that are behind main. If CI fails after rebase, the `ready-to-merge` label is removed and a comment is posted. Fix the issue, push, and re-add the label.

### Merge Conflicts

If the merge queue can't rebase your PR (conflict), it removes the label and comments. Resolve manually:

```bash
git fetch origin main
git rebase origin/main
# Fix conflicts
git push --force-with-lease
gh pr edit <number> --add-label "ready-to-merge"
```

### Parallel PR Rebase Cascade

When multiple PRs are in flight and one merges, the remaining PRs are now behind main. The merge queue handles this by auto-rebasing, but each rebase triggers a new CI run. With N parallel PRs, expect O(N^2) CI runs total.

**Mitigation strategies:**
- Limit parallel PRs to 2-3 when possible
- Sequence PRs that touch the same files (especially singletons like config files or CI workflows)
- Pre-rebase before pushing: `git fetch origin && git rebase origin/main`

### Dirty Worktrees

If `just worktree-list` shows worktrees for merged PRs, clean them up:

```bash
just worktree-sync           # Batch cleanup: pull main, delete merged branches, prune
just worktree-cleanup <task> # Single cleanup
just worktree-cleanup-all    # Nuclear: prune all orphaned worktrees + gone branches
```

### Multiple PRs in Flight

The merge queue serializes merges — only one PR merges at a time. This prevents "it passed CI but breaks main" scenarios. PRs are processed in FIFO order by when the `ready-to-merge` label was applied (not creation date).

### Agent Worktrees vs Human Worktrees

| Source | Location | Branch Pattern | Cleanup |
|--------|----------|---------------|---------|
| `just worktree-create foo` | `../<project>-foo/` | `feat/foo` | `just worktree-cleanup foo` |
| Claude Code `isolation: "worktree"` | `.claude/worktrees/agent-<hash>/` | auto-generated | `just worktree-cleanup-all` |

`just worktree-cleanup-all` prunes both patterns.

## Emergency Procedures

### Stuck Merge Queue

If a PR has the `ready-to-merge` label but hasn't merged after 10+ minutes:

```bash
# Check if CI is still running
gh run list --branch <branch> --limit 3

# Check PR state
gh pr view <number>

# If CI passed but merge didn't trigger, re-apply label
gh pr edit <number> --remove-label "ready-to-merge"
gh pr edit <number> --add-label "ready-to-merge"

# If the auto-merge workflow itself failed, check its runs
gh run list --workflow auto-merge.yml --limit 5
```

### Failed Rebase (Unrecoverable Conflicts)

If rebase conflicts are too complex:

```bash
git rebase --abort
git reset --hard origin/feat/<task>   # Reset to remote state
# Create a new branch from fresh main and cherry-pick your commits
git fetch origin main
git checkout -b feat/<task>-v2 origin/main
git cherry-pick <commit1> <commit2> ...
git push -u origin feat/<task>-v2
# Close the old PR and create a new one
gh pr close <old-number>
gh pr create --base main
```

### CI Outage (GitHub Actions Down)

If GitHub Actions is experiencing an outage:

1. Check status: https://www.githubstatus.com/
2. Do NOT force-merge PRs without CI — wait for the outage to resolve
3. Continue developing and pushing — CI will run when Actions recovers
4. If urgent, run tests locally to verify, but still wait for CI before merging

### Release / Hotfix Bypass

For releases and hotfixes that must commit directly to main:

```bash
ALLOW_MASTER_COMMIT=1 git commit -m "chore: release 1.0.0"
ALLOW_MASTER_PUSH=1 git push origin main
```

This is for repo admins only. The GitHub branch protection must allow admin bypass (enforce_admins off).

## Worktree Recipes Reference

| Recipe | Purpose |
|--------|---------|
| `just worktree-create <task>` | Create `feat/<task>` branch + worktree from `origin/main` |
| `just worktree-cleanup <task>` | Remove worktree + delete local & remote branch |
| `just worktree-cleanup-all` | Prune orphaned worktrees + delete branches with gone remotes |
| `just worktree-list` | Show all worktrees with branch name, PR status, commits-behind-main |
| `just worktree-sync` | Pull main, delete merged branches, prune worktrees |

## CI Command Reference

| Command | Purpose |
|---------|---------|
| `just watch-ci` | Watch latest CI run for current branch until complete |
| `just ci-log` | Show failed CI log for current branch |
| `just ship [title]` | Push + create PR + watch CI (all-in-one) |
| `just pr [title]` | Push + create PR |
| `gh run list --branch <branch>` | List CI runs for a branch |
| `gh run view <run-id> --log-failed` | View failed CI output |
| `gh run watch <run-id>` | Watch a running CI job |

## Infrastructure Files

| File | Role |
|------|------|
| `.githooks/pre-commit` | Main branch commit guard (+ lint, format checks) |
| `.githooks/pre-push` | Main branch push guard |
| `.github/workflows/auto-merge.yml` | Event-driven merge queue — serialized squash-merge |
| `.github/workflows/ci.yml` | CI pipeline — lint + tests + auto-label |
| `.github/workflows/pr-guard.yml` | Strip ready-to-merge label on new push |
