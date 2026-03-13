#!/usr/bin/env bash
# Unity engine lint-on-save hook — sourced by .claude/hooks/lint-on-save.sh
# $1 = path to the saved file

FILE="$1"
[ -z "$FILE" ] && exit 0

case "$FILE" in
    *.cs)
        # Check for basic C# issues
        if grep -n "Debug\.Log(" "$FILE" | grep -v "// DEBUG" | grep -v "#if.*DEBUG" | head -5; then
            echo "NOTE: Debug.Log found — consider #if DEBUG guard or structured logging"
        fi

        # Run dotnet format on the single file if available
        if command -v dotnet &>/dev/null && ls *.sln 1>/dev/null 2>&1; then
            dotnet format *.sln --include "$FILE" --verbosity quiet 2>/dev/null || true
        fi
        ;;
    *.shader | *.hlsl | *.cginc)
        echo "Shader file saved: $FILE — validate in Unity Editor"
        ;;
esac
