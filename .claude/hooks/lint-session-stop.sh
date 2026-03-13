#!/bin/bash
# SessionEnd hook: repo-wide lint sweep
# Reports all issues found so the next session (or user) can address them.

cd "$CLAUDE_PROJECT_DIR" || exit 0

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     SESSION STOP — LINT REPORT       ║"
echo "╚══════════════════════════════════════╝"
echo ""

CATEGORIES=0
ISSUES=0

# ── 1. Uncommitted changes ───────────────────────────────────────────────
echo "── Uncommitted Changes ──"
DIRTY=$(git status --porcelain 2>/dev/null | head -20)
if [ -n "$DIRTY" ]; then
    DIRTY_COUNT=$(git status --porcelain 2>/dev/null | wc -l)
    echo "  WARNING: $DIRTY_COUNT uncommitted file(s):"
    echo "$DIRTY" | sed 's/^/  /'
    [ "$DIRTY_COUNT" -gt 20 ] && echo "  ... ($((DIRTY_COUNT - 20)) more)"
    CATEGORIES=$((CATEGORIES + 1))
    ISSUES=$((ISSUES + DIRTY_COUNT))
else
    echo "  OK — working tree clean"
fi
echo ""

# ── 2. Python lint ───────────────────────────────────────────────────────
echo "── Python Lint ──"
PY_OUT=$(uv run ruff check scripts/tools/ 2>&1)
PY_EXIT=$?
if [ $PY_EXIT -ne 0 ]; then
    PY_COUNT=$(echo "$PY_OUT" | grep -cE '^\w' || echo 1)
    echo "  ISSUES: $PY_COUNT problem(s)"
    echo "$PY_OUT" | head -10 | sed 's/^/  /'
    CATEGORIES=$((CATEGORIES + 1))
    ISSUES=$((ISSUES + PY_COUNT))
else
    echo "  OK"
fi
echo ""

# ── 3. System registry validation ────────────────────────────────────────
echo "── System Registry ──"
REG_OUT=$(uv run python scripts/tools/validate_registry.py 2>&1)
REG_EXIT=$?
if [ $REG_EXIT -ne 0 ]; then
    REG_COUNT=$(echo "$REG_OUT" | grep -cE 'ERROR|FAIL' || echo 1)
    echo "  ISSUES: $REG_COUNT problem(s)"
    echo "$REG_OUT" | tail -5 | sed 's/^/  /'
    CATEGORIES=$((CATEGORIES + 1))
    ISSUES=$((ISSUES + REG_COUNT))
else
    echo "  OK"
fi
echo ""

# ── 4. Engine-specific checks ────────────────────────────────────────────
ENGINE_HOOK="$CLAUDE_PROJECT_DIR/.claude/hooks/lint-session-stop-engine.sh"
if [ -f "$ENGINE_HOOK" ]; then
    source "$ENGINE_HOOK"
fi

# ── Summary ──────────────────────────────────────────────────────────────
echo "════════════════════════════════════════"
if [ $ISSUES -gt 0 ]; then
    echo "  $ISSUES issue(s) across $CATEGORIES category(ies)"
else
    echo "  All lint checks passed"
fi
echo "════════════════════════════════════════"

# Never block session stop
exit 0
