#!/bin/bash
# PreCompact hook: capture key context before conversation compaction.
# Output is injected into the compressed context so the agent doesn't
# lose its bearings after compaction.

cd "$CLAUDE_PROJECT_DIR" || exit 0

echo "=== CONTEXT SNAPSHOT (pre-compaction) ==="
echo ""

# Current branch
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "Branch: $BRANCH"

# Uncommitted changes summary
DIRTY_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "$DIRTY_COUNT" -gt 0 ]; then
    echo "Uncommitted changes: $DIRTY_COUNT file(s)"
    git status --porcelain 2>/dev/null | head -10 | sed 's/^/  /'
    [ "$DIRTY_COUNT" -gt 10 ] && echo "  ... ($((DIRTY_COUNT - 10)) more)"
else
    echo "Working tree: clean"
fi

# Recent commits on this branch (not on main)
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "unknown" ]; then
    COMMITS=$(git log --oneline origin/main..HEAD 2>/dev/null | head -10)
    if [ -n "$COMMITS" ]; then
        COMMIT_COUNT=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "?")
        echo ""
        echo "Commits on $BRANCH ($COMMIT_COUNT total):"
        echo "$COMMITS" | sed 's/^/  /'
        [ "$COMMIT_COUNT" -gt 10 ] && echo "  ... ($((COMMIT_COUNT - 10)) more)"
    fi
fi

# PR status
if command -v gh &>/dev/null && [ "$BRANCH" != "main" ]; then
    PR_JSON=$(gh pr list --head "$BRANCH" --state all --json number,state,title --limit 1 2>/dev/null || echo "[]")
    PR_NUM=$(echo "$PR_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['number'] if d else '')" 2>/dev/null || echo "")
    if [ -n "$PR_NUM" ]; then
        PR_STATE=$(echo "$PR_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['state'])" 2>/dev/null || echo "?")
        PR_TITLE=$(echo "$PR_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['title'])" 2>/dev/null || echo "?")
        echo ""
        echo "PR: #${PR_NUM} (${PR_STATE}) -- ${PR_TITLE}"
    fi
fi

echo ""
echo "=== END CONTEXT SNAPSHOT ==="

exit 0
