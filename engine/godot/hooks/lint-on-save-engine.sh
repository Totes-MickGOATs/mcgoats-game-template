#!/usr/bin/env bash
# Engine-specific lint-on-save for Godot
# Called by .claude/hooks/lint-on-save.sh when a .gd file is saved

FILE="$1"
if [[ "$FILE" == *.gd ]]; then
    if command -v gdlint &>/dev/null; then
        gdlint "$FILE" 2>&1
    fi
    if command -v gdformat &>/dev/null; then
        gdformat --check "$FILE" 2>&1
    fi
fi
