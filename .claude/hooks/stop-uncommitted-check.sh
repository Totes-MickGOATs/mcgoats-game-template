#!/bin/bash
# Stop hook: warn about uncommitted changes when the model finishes responding.
# Catches the "forgot to commit" pattern.

cd "$CLAUDE_PROJECT_DIR" || exit 0

BRANCH=$(git branch --show-current 2>/dev/null)
[[ "$BRANCH" == "main" ]] && exit 0
[[ -z "$BRANCH" ]] && exit 0

# Only warn if there are uncommitted code files (ignore untracked noise)
# Engine-specific extensions can be added here
DIRTY_CODE=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(gd|py|cs|cpp|h|tscn|tres)$' | head -5)
if [ -n "$DIRTY_CODE" ]; then
    COUNT=$(git diff --name-only HEAD 2>/dev/null | grep -cE '\.(gd|py|cs|cpp|h|tscn|tres)$')
    echo ""
    echo "NOTE: $COUNT uncommitted code file(s) on $BRANCH:"
    echo "$DIRTY_CODE" | sed 's/^/  /'
    [ "$COUNT" -gt 5 ] && echo "  ... ($((COUNT - 5)) more)"
fi

exit 0
