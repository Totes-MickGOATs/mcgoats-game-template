#!/usr/bin/env bash
# Seed Unity Library cache in worktrees
MAIN_LIBRARY="$(git rev-parse --show-toplevel)/Library"
if [ -d "$MAIN_LIBRARY" ] && [ ! -d "Library" ]; then
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        cmd //c "mklink /J \"$(pwd -W)\\Library\" \"$(cd "$MAIN_LIBRARY" && pwd -W)\""
    else
        ln -s "$MAIN_LIBRARY" Library
    fi
    echo "Unity Library cache seeded."
fi
