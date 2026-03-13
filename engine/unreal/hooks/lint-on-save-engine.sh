#!/usr/bin/env bash
# Engine-specific lint-on-save for Unreal (stub)
FILE="$1"
if [[ "$FILE" == *.cpp || "$FILE" == *.h ]]; then
    echo "C++ file saved: $FILE"
    # Future: clang-format -i "$FILE"
fi
