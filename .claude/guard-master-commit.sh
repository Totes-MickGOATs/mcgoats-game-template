#!/bin/bash
# Claude Code PreToolUse hook: block git commit on main branch.
# This hook cannot be bypassed by --no-verify or any git flag.
# It runs BEFORE the command executes.

CMD=$(jq -r ".tool_input.command // empty")

# Only check git commit commands
if ! echo "$CMD" | grep -qE '\bgit\b.*\bcommit\b'; then
    exit 0
fi

# Block --no-verify (never allowed in this project)
if echo "$CMD" | grep -qE '\-\-no-verify'; then
    echo "BLOCKED: --no-verify is not allowed in this project." >&2
    echo "Fix the pre-commit hook issue instead of bypassing it." >&2
    exit 1
fi

# Check current branch
BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" branch --show-current 2>/dev/null)

if [ "$BRANCH" = "main" ]; then
    # Allow if ALLOW_MASTER_COMMIT is set in the command
    if echo "$CMD" | grep -qE 'ALLOW_MASTER_COMMIT=1'; then
        exit 0
    fi
    echo "BLOCKED: Cannot commit on main branch." >&2
    echo "" >&2
    echo "ALL code changes must go through feature branches + PRs." >&2
    echo "" >&2
    echo "If you are a subagent (isolation: \"worktree\"), you should" >&2
    echo "already be on a feat/ branch. Verify:" >&2
    echo "  git branch --show-current" >&2
    echo "" >&2
    echo "If you are the main agent or on main by mistake:" >&2
    echo "  1. Do NOT edit files on main — dispatch a subagent instead" >&2
    echo "  2. Use: Agent(prompt=..., isolation=\"worktree\")" >&2
    echo "  3. Or manually: just worktree-create <task-name>" >&2
    echo "" >&2
    echo "Full guide: .agents/skills/branch-workflow/SKILL.md" >&2
    exit 1
fi

exit 0
