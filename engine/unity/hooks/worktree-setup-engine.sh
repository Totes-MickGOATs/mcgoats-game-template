#!/usr/bin/env bash
# Unity engine worktree setup — sourced by .claude/hooks/worktree-setup.sh
# Creates junction/symlink to main repo's Library/ for fast import cache sharing

MAIN_REPO="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$MAIN_REPO" ]; then
    echo "WARNING: Could not determine main repo path"
    exit 0
fi

# In a worktree, the main repo is the original checkout
WORKTREE_ROOT="$(pwd)"
MAIN_LIBRARY="$MAIN_REPO/Library"

if [ -d "$MAIN_LIBRARY" ] && [ ! -d "$WORKTREE_ROOT/Library" ]; then
    echo "Creating Library junction for fast import cache..."
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        # Windows: directory junction
        cmd //c "mklink /J \"$(cygpath -w "$WORKTREE_ROOT/Library")\" \"$(cygpath -w "$MAIN_LIBRARY")\"" 2>/dev/null
    else
        # Unix: symlink
        ln -s "$MAIN_LIBRARY" "$WORKTREE_ROOT/Library"
    fi

    if [ -d "$WORKTREE_ROOT/Library" ]; then
        echo "Library cache linked successfully"
    else
        echo "WARNING: Failed to link Library — Unity will do a full reimport"
    fi
fi
