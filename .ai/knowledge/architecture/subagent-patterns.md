# Subagent Patterns & Lessons Learned

Hard-won patterns for working with Claude Code subagents in a multi-PR workflow. Every pattern here was learned through real failures that cost significant time. Read before dispatching parallel subagents.

## Pattern 1: Singleton File Bottleneck

**Problem:** Certain files are edited by nearly every feature branch -- `.claude/settings.json`, `justfile`, `pyproject.toml`, CI workflow files. When multiple subagents edit these files in parallel, every merge creates conflicts in the remaining PRs, causing a cascade of rebase cycles.

**Real example:** Three parallel subagents all edited `.claude/settings.json` (adding various hooks -- PostToolUse, SubagentStop, Stop, PreCompact, WorktreeCreate, SessionEnd). Every merge created conflicts in the next PR, causing a cascade of rebase cycles. Each cycle took ~5 minutes of CI, turning a 10-minute task into 45+ minutes of merge queue churn.

**How to avoid:**
- When dispatching parallel subagents, identify shared singleton files (`settings.json`, `justfile`, `pyproject.toml`, `ci.yml`, pre-commit hooks) and **sequence PRs that touch them** rather than parallelizing.
- If you must parallelize, have the FIRST subagent make ALL changes to the singleton file, and other subagents only create new files (which don't conflict).
- Batch related changes into a single PR when possible -- one commit per change is fine, but they should be on the same branch.
- Same principle applies to any high-contention file that many changes touch.

**Rule of thumb:** If two subagents will both edit the same file, put those changes on the same branch.

## Pattern 2: Rebase Cascade Cost

**Problem:** The auto-merge queue processes PRs FIFO. When PR A merges, PR B must rebase onto the new main, re-run CI, and wait for auto-merge. If PR C is also open, it waits for B, then rebases itself. This creates O(N^2) CI runs.

**Real example:** Four parallel PRs took over 45 minutes to fully merge despite each having less than 1 minute of actual changes:
- PR A merged first (clean)
- PR B needed 1 rebase cycle (~5 min CI)
- PR C needed 1 rebase cycle (~5 min CI)
- PR D needed 3+ rebase cycles (~15+ min CI) due to structural conflicts

**Cost model:** N parallel PRs = up to N*(N-1)/2 CI runs in the worst case. With 5-minute CI, 4 PRs = potentially 30 minutes of queue time.

**How to avoid:**
- For 2 parallel PRs with no file overlap: fine, go parallel.
- For 3+ PRs OR any file overlap: sequence them (dispatch subagent 2 after subagent 1's PR merges).
- If parallelizing, ensure ZERO file overlap between subagents -- including transitive dependencies like lock files (`uv.lock`, `package-lock.json`).
- Monitor the merge queue actively; don't fire-and-forget parallel PRs.
- Consider batching related changes into fewer, larger PRs rather than many small ones.

**Decision matrix:**

| Situation | Approach |
|-----------|----------|
| 2 PRs, no file overlap | Parallel OK |
| 2 PRs, shared file | Sequence |
| 3+ PRs, no overlap | Parallel with caution, monitor queue |
| 3+ PRs, any overlap | Sequence all overlapping ones |
| Config file changes | Always single branch |

## Pattern 3: Verify Subagent Diffs

**Problem:** When a subagent reports "CI green, PR created", that does NOT mean the change is correct. CI passing means "no regressions detected" -- it doesn't validate that new functionality is wired correctly, configs are complete, or nothing was accidentally dropped.

**Real example:** A subagent's PR had three problems that CI did not catch:
1. Used `SessionStop` (an invalid event name) instead of `SessionEnd` -- the hook simply would never fire (silent failure).
2. Dropped an existing `py_compile` PostToolUse hook entirely instead of adding alongside it -- lost existing functionality.
3. Created a `settings.json` that was structurally incomplete compared to what had already been configured -- started from a stale version.

All three passed CI because the JSON was valid and the hooks would silently not fire. The issues were only caught during manual review of the diff during merge conflict resolution.

**How to avoid:**
- After a subagent completes, inspect the actual diff:
  ```bash
  gh pr diff <num>                              # Full diff
  gh api repos/.../pulls/N/files --jq '.[].filename'  # Changed files
  gh pr diff <num> -- <specific_file>           # Diff for a specific file
  ```
- For config files (settings.json, ci.yml, etc.), read the FULL file content in the PR, not just the diff -- check for dropped functionality.
- Especially verify singleton config files where the subagent may have started from a stale version of the file.
- Check for DROPPED functionality, not just added functionality. A subagent replacing a file may lose things that were already there.
- "CI green" means "no regressions detected" -- it does not validate correctness of new additions that have no test coverage.

**Checklist after subagent completes:**
1. Review changed file list -- are these the files you expected?
2. For each config/singleton file -- is the full content correct, not just the additions?
3. Are there any files that SHOULD have changed but didn't?
4. Do new hook/event names match the schema exactly?

## Pattern 4: Parallel PR Rebase

**Problem:** When multiple PRs are open in parallel, earlier merges make later PRs stale. GitHub shows `mergeStateStatus: DIRTY` and the PR cannot merge until rebased.

**Real example:** After dispatching parallel subagents, the first PR merged cleanly. The second PR's base was now stale and conflicted with the merged changes. GitHub blocked the merge with DIRTY status. The subagent had to be resumed to rebase and force-push, adding another CI cycle.

**How to avoid:**
- After dispatching parallel subagents, monitor the merge queue -- don't assume all PRs will auto-merge cleanly.
- When a PR shows CONFLICTING or DIRTY, either:
  - Resume the original subagent to rebase: `git fetch origin && git rebase origin/main`, resolve conflicts, force-push
  - Or dispatch a new subagent to handle the rebase
- When resolving conflicts between parallel PRs, keep ALL changes from both branches -- they were independently correct.
- Check PR status after each merge: `gh pr view <num> --json mergeable,mergeStateStatus`
- Consider sequencing PRs that edit the same files rather than parallelizing them.

**Rebase workflow for stale PRs:**
```bash
git fetch origin
git rebase origin/main
# Resolve any conflicts (keep changes from both sides)
git push --force-with-lease
# CI re-runs automatically
```

## Pattern 5: Hook Event Names

**Problem:** Claude Code hook event names must match the schema exactly. Invalid names are silently ignored or fail schema validation, and there's no runtime error -- the hook simply never fires.

**Real example:** A subagent used `SessionStop` (which doesn't exist) instead of `SessionEnd`. The hook config was valid JSON and passed CI, but the hook would never have triggered. The error was caught during manual review but wasted a rebase cycle fixing it.

**Valid event names (as of 2026-03):**
- `PreToolUse` -- before a tool is called
- `PostToolUse` -- after a tool call succeeds
- `PostToolUseFailure` -- after a tool call fails
- `Notification` -- on notification events
- `UserPromptSubmit` -- when user submits a prompt
- `SessionStart` -- when a session begins
- `SessionEnd` -- when a session ends (NOT `SessionStop`)
- `Stop` -- when the model finishes a response turn
- `SubagentStart` -- when a subagent starts
- `SubagentStop` -- when a subagent finishes
- `PreCompact` -- before context compression
- `PermissionRequest` -- when a permission is requested
- `Setup` -- during setup
- `TeammateIdle` -- when a teammate becomes idle
- `TaskCompleted` -- when a task completes
- `Elicitation` -- when an elicitation starts
- `ElicitationResult` -- when an elicitation completes
- `ConfigChange` -- when configuration changes
- `WorktreeCreate` -- when a worktree is created
- `WorktreeRemove` -- when a worktree is removed
- `InstructionsLoaded` -- when instructions are loaded

**How to avoid:**
- Reference this list when writing hook configs. Do not guess event names.
- `SessionEnd` = when the session ends (use for cleanup, sweeps)
- `Stop` = when the model finishes a response turn (use for per-turn checks)
- `SubagentStop` = when a subagent finishes (use for quality gates)
- `PreCompact` = before context compression (use for saving state)

## Decision Framework: When to Parallelize

### Safe to parallelize
- Subagents that create entirely new, independent files (new scripts, new tests, new assets)
- Changes to different subsystems with no shared files
- Documentation updates to different directories

### Must sequence
- Any changes to `.claude/settings.json`
- Any changes to `justfile` or build configuration
- Any changes to `pyproject.toml`, `package.json`, or dependency files
- Any changes to CI workflow files (`.github/workflows/`)
- Any changes to git hooks (`.githooks/`)
- Any changes where two subagents edit the same file

### Rule of thumb
- N parallel PRs = O(N^2) CI runs due to rebase cascade
- 2 independent PRs: ~10 min total (fine)
- 4 independent PRs: ~30 min total (acceptable if truly independent)
- 4 PRs with file overlap: 45+ min and manual intervention needed (avoid)
- When in doubt, sequence. The time saved by parallelizing is often lost to rebase cascades and manual conflict resolution.
