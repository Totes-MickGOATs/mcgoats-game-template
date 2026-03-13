# Game Project Task Runner
# Usage: just <recipe> [args]

# Import engine-specific recipes if available
import? 'justfile.engine'

# Default: list available recipes
default:
    @just --list

# --- Setup ---

# Install dependencies, configure hooks, verify tooling
setup:
    uv sync
    git config core.hooksPath .githooks
    @echo "--- Python dependencies installed, git hooks configured ---"
    @echo "--- Setup complete ---"

# One-command project initialization (interactive)
quick-start:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🎮 mcgoats-game-template Quick Start"
    echo ""
    echo "Available engines:"
    echo "  1) godot   — Godot 4.x (GDScript) [Full support]"
    echo "  2) unity   — Unity (C#) [Basic stubs]"
    echo "  3) unreal  — Unreal Engine (C++) [Empty stubs]"
    echo ""
    read -p "Select engine (godot/unity/unreal): " engine
    if [[ -z "$engine" ]]; then
        echo "No engine selected. Aborting."
        exit 1
    fi
    echo ""
    echo "Running setup..."
    bash tools/setup-engine.sh "$engine"
    echo ""
    echo "Installing Python dependencies..."
    uv sync
    echo ""
    echo "Configuring git hooks..."
    git config core.hooksPath .githooks
    chmod +x .githooks/* .claude/hooks/* .claude/*.sh 2>/dev/null || true
    echo ""
    echo "✅ Quick start complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Set up GitHub branch protection and MERGE_TOKEN secret"
    echo "     Run: /dev:init-project for a guided walkthrough"
    echo "  2. Customize README.md and CLAUDE.md for your project"
    echo "  3. Start building: just worktree-create first-feature"

# --- Linting ---

# Lint Python scripts
python-lint:
    uv run ruff check scripts/tools/

# Format-check Python scripts
python-format-check:
    uv run ruff format --check scripts/tools/

# Auto-format Python scripts
python-format:
    uv run ruff format scripts/tools/

# Auto-format then lint (pre-push check)
check: python-lint validate-registry validate-docs

# Validate system manifests (file existence, ownership, dependencies)
validate-registry:
    uv run python scripts/tools/validate_registry.py

# --- Testing ---

# Show test coverage report
test-coverage:
    uv run python scripts/tools/test_coverage_report.py

# CI coverage check: compare against baseline
test-coverage-ci:
    uv run python scripts/tools/test_coverage_report.py --ci

# Full preflight: lint + validate (run before pushing)
preflight: python-lint validate-registry validate-docs
    @echo "--- Preflight passed ---"

# --- Changelog ---

# Generate changelog from conventional commits
changelog:
    git-cliff -o CHANGELOG.md
    @echo "--- CHANGELOG.md updated ---"

# Preview upcoming changelog (unreleased commits)
changelog-preview:
    git-cliff --unreleased

# --- Release ---

# Create a tagged release from master
release version:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Releasing {{ version }}..."
    BRANCH=$(git branch --show-current)
    if [ "$BRANCH" != "master" ]; then
        echo "ERROR: Releases must be created from master (currently on $BRANCH)"
        exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
        echo "ERROR: Working tree is dirty. Commit or stash changes first."
        exit 1
    fi
    git-cliff --tag "v{{ version }}" -o CHANGELOG.md
    git add CHANGELOG.md
    ALLOW_MASTER_COMMIT=1 git commit -m "chore: release {{ version }}"
    git tag -a "v{{ version }}" -m "Release {{ version }}"
    echo "Tagged v{{ version }}. Run 'ALLOW_MASTER_PUSH=1 git push && git push --tags' to trigger CI."

# --- Worktree Management ---

# Create an isolated worktree for a task (branch: feat/<task> from origin/master)
worktree-create task:
    #!/usr/bin/env bash
    set -euo pipefail
    BRANCH="feat/{{ task }}"
    # Use parent directory naming convention: <project>-<task>
    PROJECT_NAME=$(basename "$(pwd)")
    WORKTREE_DIR="../${PROJECT_NAME}-{{ task }}"
    echo "Pulling latest master from remote..."
    git fetch origin master
    git update-ref refs/heads/master refs/remotes/origin/master
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        echo "Branch $BRANCH already exists. Checking out in worktree..."
        git worktree add "$WORKTREE_DIR" "$BRANCH"
    else
        git worktree add -b "$BRANCH" "$WORKTREE_DIR" origin/master
    fi
    echo "--- Worktree created at $WORKTREE_DIR (branch: $BRANCH) ---"
    echo "cd $WORKTREE_DIR to start working"

# Remove a task's worktree and delete its local + remote branch
worktree-cleanup task:
    #!/usr/bin/env bash
    set -euo pipefail
    BRANCH="feat/{{ task }}"
    PROJECT_NAME=$(basename "$(pwd)")
    WORKTREE_DIR="../${PROJECT_NAME}-{{ task }}"
    if [ -d "$WORKTREE_DIR" ]; then
        git worktree remove "$WORKTREE_DIR" --force 2>/dev/null || true
        echo "Removed worktree $WORKTREE_DIR"
    fi
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        git branch -D "$BRANCH" 2>/dev/null || true
        echo "Deleted local branch $BRANCH"
    fi
    if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
        git push origin --delete "$BRANCH" 2>/dev/null || true
        echo "Deleted remote branch $BRANCH"
    fi
    git fetch origin master --quiet 2>/dev/null || true
    git update-ref refs/heads/master refs/remotes/origin/master 2>/dev/null || true
    echo "Local master -> $(git rev-parse --short origin/master 2>/dev/null || echo '?')"
    echo "--- Cleanup complete for {{ task }} ---"

# Prune orphaned worktrees and branches with gone remotes
worktree-cleanup-all:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Pruning orphaned worktrees..."
    git worktree prune
    echo "Fetching remote state..."
    git fetch origin --prune
    GONE_BRANCHES=$(git branch -vv | grep ': gone]' | awk '{print $1}' || true)
    if [ -n "$GONE_BRANCHES" ]; then
        echo "Deleting branches with gone remotes:"
        echo "$GONE_BRANCHES"
        echo "$GONE_BRANCHES" | xargs git branch -D 2>/dev/null || true
    else
        echo "No stale branches found."
    fi
    git update-ref refs/heads/master refs/remotes/origin/master 2>/dev/null || true
    echo "Local master -> $(git rev-parse --short origin/master 2>/dev/null || echo '?')"
    echo "--- Cleanup-all complete ---"

# Sync master, delete merged branches, prune worktrees
worktree-sync:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Fetching latest master..."
    git fetch origin master
    git update-ref refs/heads/master refs/remotes/origin/master
    MASTER_SHA=$(git rev-parse --short origin/master)
    echo "Local master -> $MASTER_SHA"
    echo "Deleting branches already merged into origin/master..."
    MERGED=$(git branch --merged origin/master | grep -vE '^\*|master' | sed 's/^[ \t]*//' || true)
    if [ -n "$MERGED" ]; then
        echo "$MERGED" | xargs git branch -d 2>/dev/null || true
        echo "Deleted: $MERGED"
    else
        echo "No merged branches to clean."
    fi
    git worktree prune
    echo "--- Sync complete ---"

# List all worktrees with branch name and PR status
worktree-list:
    #!/usr/bin/env bash
    set -euo pipefail
    git fetch origin master --quiet 2>/dev/null || true
    git update-ref refs/heads/master refs/remotes/origin/master 2>/dev/null || true
    MASTER_SHA=$(git rev-parse origin/master 2>/dev/null || git rev-parse master)
    printf "%-45s %-30s %-6s %s\n" "WORKTREE" "BRANCH" "BEHIND" "PR STATUS"
    printf "%-45s %-30s %-6s %s\n" "--------" "------" "------" "---------"
    git worktree list --porcelain | while IFS= read -r line; do
        case "$line" in
            "worktree "*)
                WT_PATH="${line#worktree }"
                ;;
            "branch "*)
                BRANCH="${line#branch refs/heads/}"
                BEHIND=$(git rev-list --count "$BRANCH..${MASTER_SHA}" 2>/dev/null || echo "?")
                PR_STATUS=""
                if [ "$BRANCH" != "master" ] && command -v gh >/dev/null 2>&1; then
                    PR_JSON=$(gh pr list --head "$BRANCH" --state all --json number,state --limit 1 2>/dev/null || echo "[]")
                    PR_NUM=$(echo "$PR_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['number'] if d else '')" 2>/dev/null || echo "")
                    if [ -n "$PR_NUM" ]; then
                        PR_STATE=$(echo "$PR_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['state'])" 2>/dev/null || echo "?")
                        PR_STATUS="#${PR_NUM} ${PR_STATE}"
                    else
                        PR_STATUS="NO PR"
                    fi
                fi
                printf "%-45s %-30s %-6s %s\n" "$WT_PATH" "$BRANCH" "$BEHIND" "$PR_STATUS"
                ;;
        esac
    done

# --- Fast Iteration ---

# Push current branch and create PR in one command
pr title="":
    #!/usr/bin/env bash
    set -euo pipefail
    BRANCH=$(git branch --show-current)
    if [ "$BRANCH" = "master" ]; then
        echo "ERROR: Cannot create PR from master. Use a feature branch."
        exit 1
    fi
    echo "Rebasing onto latest master..."
    git fetch origin master --quiet
    if ! git rebase origin/master; then
        echo "ERROR: Rebase failed. Resolve conflicts, then retry."
        git rebase --abort 2>/dev/null || true
        exit 1
    fi
    echo "Pushing $BRANCH..."
    git push --force-with-lease -u origin "$BRANCH"
    EXISTING=$(gh pr list --head "$BRANCH" --state open --json number --limit 1 2>/dev/null || echo "[]")
    EXISTING_NUM=$(echo "$EXISTING" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['number'] if d else '')" 2>/dev/null || echo "")
    if [ -n "$EXISTING_NUM" ]; then
        PR_URL=$(gh pr view "$EXISTING_NUM" --json url -q '.url')
        echo "--- PR #${EXISTING_NUM} already exists (updated): $PR_URL ---"
        exit 0
    fi
    PR_TITLE="{{ title }}"
    if [ -z "$PR_TITLE" ]; then
        PR_TITLE=$(echo "$BRANCH" | sed 's|^feat/||' | tr '-' ' ' | tr '_' ' ')
    fi
    echo "Creating PR..."
    PR_BODY="## Summary\nFeature branch\n\n## Test plan\n- [ ] CI passes\n- [ ] Tests written and passing"
    gh pr create --base master --title "$PR_TITLE" --body "$(echo -e "$PR_BODY")"
    NEW_PR_NUM=$(gh pr list --head "$BRANCH" --state open --json number -q '.[0].number' 2>/dev/null || echo "")
    if [ -n "$NEW_PR_NUM" ]; then
        gh pr merge "$NEW_PR_NUM" --auto --squash 2>/dev/null || true
        echo "Auto-merge enabled for PR #${NEW_PR_NUM}"
    fi
    echo "--- PR created. Auto-merge enabled. ---"

# Watch CI status for current branch
watch-ci:
    #!/usr/bin/env bash
    set -euo pipefail
    BRANCH=$(git branch --show-current)
    echo "Finding latest CI run for $BRANCH..."
    RUN_ID=""
    for i in 1 2 3; do
        RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId,status -q '.[0].databaseId' 2>/dev/null || echo "")
        if [ -n "$RUN_ID" ]; then break; fi
        echo "Waiting for CI run to appear..."
        sleep 3
    done
    if [ -z "$RUN_ID" ]; then
        echo "No CI runs found for branch $BRANCH. Push first?"
        exit 1
    fi
    echo "Watching run $RUN_ID..."
    gh run watch "$RUN_ID" --exit-status && echo "--- CI PASSED ---" || echo "--- CI FAILED --- Run: just ci-log"

# Show failed CI log for current branch
ci-log:
    #!/usr/bin/env bash
    set -euo pipefail
    BRANCH=$(git branch --show-current)
    RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || echo "")
    if [ -z "$RUN_ID" ]; then
        echo "No CI runs found for branch $BRANCH."
        exit 1
    fi
    echo "=== Failed logs for run $RUN_ID ==="
    gh run view "$RUN_ID" --log-failed

# One-command: rebase, push, create PR, watch CI
ship title="":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== SHIP IT ==="
    just pr "{{ title }}"
    echo ""
    just watch-ci
    echo ""
    BRANCH=$(git branch --show-current)
    echo "Waiting for PR to merge..."
    for i in $(seq 1 20); do
        STATE=$(gh pr view --json state -q '.state' 2>/dev/null || echo "UNKNOWN")
        if [ "$STATE" = "MERGED" ]; then
            echo "--- PR MERGED ---"
            exit 0
        elif [ "$STATE" = "CLOSED" ]; then
            echo "--- PR was CLOSED (not merged) ---"
            exit 1
        fi
        sleep 15
    done
    echo "--- PR still open after 5 minutes. Check merge queue status. ---"

# Check CLAUDE.md freshness
validate-docs:
    uv run python scripts/tools/validate_claude_md.py

# Check CLAUDE.md freshness (CI mode)
validate-docs-ci:
    uv run python scripts/tools/validate_claude_md.py --ci --threshold 30

# Check for template upstream drift
check-template-sync:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! git remote | grep -q template; then
        echo "No 'template' remote configured."
        echo "Add it: git remote add template https://github.com/Totes-MickGOATs/mcgoats-game-template.git"
        exit 0
    fi
    git fetch template master --quiet 2>/dev/null || { echo "Could not fetch template remote."; exit 0; }
    BEHIND=$(git rev-list --count HEAD..template/master 2>/dev/null || echo "0")
    if [ "$BEHIND" -gt 0 ]; then
        echo "Template has $BEHIND new commit(s). Consider merging:"
        echo "  git fetch template && git merge template/master --no-ff"
        git log --oneline HEAD..template/master | head -10
    else
        echo "Up to date with template."
    fi

# Clean build artifacts
clean:
    rm -rf builds/
    find . -name "*.pyc" -delete
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    @echo "Cleaned."
