#!/usr/bin/env bash
# Unity engine pre-commit hook — sourced by .githooks/pre-commit

# Check for missing .meta files in staged Assets/
staged_assets=$(git diff --cached --name-only --diff-filter=A -- 'Assets/*' | grep -v '\.meta$')
if [ -n "$staged_assets" ]; then
    missing_meta=0
    while IFS= read -r file; do
        if ! git diff --cached --name-only | grep -qF "${file}.meta"; then
            echo "ERROR: Missing .meta file for staged asset: ${file}"
            echo "  Open the project in Unity Editor to generate .meta files"
            missing_meta=1
        fi
    done <<< "$staged_assets"

    if [ "$missing_meta" -ne 0 ]; then
        exit 1
    fi
fi

# Check for orphaned .meta files (staged .meta without corresponding asset)
staged_metas=$(git diff --cached --name-only --diff-filter=A -- 'Assets/*.meta')
if [ -n "$staged_metas" ]; then
    while IFS= read -r meta; do
        asset="${meta%.meta}"
        if ! git diff --cached --name-only | grep -qF "$asset"; then
            # Also check if the asset exists on disk (might not be staged)
            if [ ! -e "$asset" ]; then
                echo "WARNING: Orphaned .meta file staged: ${meta}"
            fi
        fi
    done <<< "$staged_metas"
fi

# Check C# files for common issues
staged_cs=$(git diff --cached --name-only --diff-filter=ACM -- '*.cs')
if [ -n "$staged_cs" ]; then
    while IFS= read -r file; do
        # Check for namespace declaration (all scripts should have one)
        if ! grep -q "^namespace " "$file" 2>/dev/null; then
            echo "WARNING: No namespace declaration in: ${file}"
        fi
    done <<< "$staged_cs"
fi
