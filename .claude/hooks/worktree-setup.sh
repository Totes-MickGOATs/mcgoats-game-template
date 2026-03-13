#!/bin/bash
# WorktreeCreate hook: auto-setup new worktrees
# NOTE: Must always produce output — Claude Code treats no output as failure.
cd "$CLAUDE_PROJECT_DIR" || { echo "worktree-setup: skipped (no project dir)"; exit 0; }

# Source engine-specific worktree setup if it exists
ENGINE_HOOK="$CLAUDE_PROJECT_DIR/.claude/hooks/worktree-setup-engine.sh"
if [ -f "$ENGINE_HOOK" ]; then
    source "$ENGINE_HOOK"
else
    echo "worktree-setup: no engine-specific setup configured"
fi
exit 0
