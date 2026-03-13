#!/usr/bin/env bash
# Engine-specific pre-commit checks for Unreal (stub)

STAGED_CPP=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(cpp|h|hpp)$' || true)
if [ -n "$STAGED_CPP" ]; then
    echo "C++ files staged. Consider running clang-format/clang-tidy."
    # Future: clang-format --dry-run --Werror $STAGED_CPP
fi
