#!/usr/bin/env bash
# Engine-specific pre-commit checks for Godot

# GDScript lint on staged .gd files
STAGED_GD=$(git diff --cached --name-only --diff-filter=ACM | grep '\.gd$' || true)
if [ -n "$STAGED_GD" ]; then
    echo "Linting GDScript files..."
    if command -v gdlint &>/dev/null; then
        echo "$STAGED_GD" | xargs gdlint
        if [ $? -ne 0 ]; then
            echo "GDScript lint failed. Fix issues before committing."
            exit 1
        fi
    else
        echo "Warning: gdlint not found. Skipping GDScript lint."
    fi
fi

# GDScript parse check
if [ -n "$STAGED_GD" ]; then
    if command -v gdparse &>/dev/null; then
        echo "$STAGED_GD" | while read -r f; do
            gdparse "$f" >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "GDScript parse error: $f"
                exit 1
            fi
        done
    fi
fi
