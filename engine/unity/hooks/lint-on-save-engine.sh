#!/usr/bin/env bash
# Engine-specific lint-on-save for Unity
FILE="$1"
if [[ "$FILE" == *.cs ]]; then
    echo "C# file saved: $FILE"
    # Future: dotnet format "$FILE"
fi
