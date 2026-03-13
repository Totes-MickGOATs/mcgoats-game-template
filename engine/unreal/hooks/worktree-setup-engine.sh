#!/usr/bin/env bash
# Seed Unreal cache in worktrees (stub)
MAIN_DDC="$(git rev-parse --show-toplevel)/DerivedDataCache"
if [ -d "$MAIN_DDC" ] && [ ! -d "DerivedDataCache" ]; then
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        cmd //c "mklink /J \"$(pwd -W)\\DerivedDataCache\" \"$(cd "$MAIN_DDC" && pwd -W)\""
    else
        ln -s "$MAIN_DDC" DerivedDataCache
    fi
    echo "Unreal DerivedDataCache seeded."
fi
