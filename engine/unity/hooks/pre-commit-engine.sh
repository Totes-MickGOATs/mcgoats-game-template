#!/usr/bin/env bash
# Engine-specific pre-commit checks for Unity
# Placeholder — add C# analyzers as needed

STAGED_CS=$(git diff --cached --name-only --diff-filter=ACM | grep '\.cs$' || true)
if [ -n "$STAGED_CS" ]; then
    echo "C# files staged. Consider running analyzers before committing."
    # Future: dotnet format --verify-no-changes
fi
