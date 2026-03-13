#!/bin/bash
# PostToolUse hook: per-file lint after Edit/Write
# Dispatches to engine-specific linter based on file extension.
# Warns but never blocks.

FILE=$(jq -r ".tool_input.file_path // empty")
[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

cd "$CLAUDE_PROJECT_DIR" || exit 0

# Make path relative for tools
REL_FILE="${FILE#$CLAUDE_PROJECT_DIR/}"
REL_FILE=$(echo "$REL_FILE" | sed 's|\\|/|g')

# If file doesn't exist (deleted), skip
[ -f "$REL_FILE" ] || exit 0

# ── Python files ────────────────────────────────────────────────────────────
if [[ "$FILE" == *.py ]]; then
    OUTPUT=$(uv run ruff check "$REL_FILE" 2>&1)
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo "ruff issues in $REL_FILE:"
        echo "$OUTPUT"
    fi
    exit 0
fi

# ── Engine-specific dispatch ────────────────────────────────────────────────
# Source engine-specific lint hook if it exists (pass FILE as $1)
ENGINE_HOOK="$CLAUDE_PROJECT_DIR/.claude/hooks/lint-on-save-engine.sh"
if [ -f "$ENGINE_HOOK" ]; then
    source "$ENGINE_HOOK" "$FILE"
fi

exit 0
