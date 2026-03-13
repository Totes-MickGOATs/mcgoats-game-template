#!/usr/bin/env python3
"""Validate CLAUDE.md freshness against directory modification dates.

Checks if CLAUDE.md files are stale relative to their directories.
A CLAUDE.md is "stale" if its directory has been modified more recently
by more than STALE_THRESHOLD_DAYS.

Usage:
    python scripts/tools/validate_claude_md.py [--ci] [--threshold DAYS]

Options:
    --ci          Exit with code 1 if stale files found (for CI enforcement)
    --threshold   Days before a CLAUDE.md is considered stale (default: 14)
"""

import argparse
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

EXCLUDE_DIRS = {
    ".git", ".godot", ".venv", "__pycache__", "node_modules",
    "Library", "Temp", "Obj", "Intermediate", "Saved",
}


def get_git_date(path: str) -> str | None:
    """Get the last git commit date for a file/directory (ISO format)."""
    try:
        result = subprocess.run(
            ["git", "log", "-1", "--format=%aI", "--", path],
            capture_output=True, text=True, timeout=10,
        )
        date_str = result.stdout.strip()
        return date_str if date_str else None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def get_dir_latest_date(directory: Path) -> str | None:
    """Get the most recent git commit date for any non-CLAUDE.md file in a directory."""
    try:
        result = subprocess.run(
            ["git", "log", "-1", "--format=%aI", "--",
             str(directory / "*"), ":(exclude)" + str(directory / "CLAUDE.md")],
            capture_output=True, text=True, timeout=10,
        )
        date_str = result.stdout.strip()
        return date_str if date_str else None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def days_between(date1: str, date2: str) -> int:
    """Calculate days between two ISO date strings."""
    d1 = datetime.fromisoformat(date1)
    d2 = datetime.fromisoformat(date2)

    if d1.tzinfo is None:
        d1 = d1.replace(tzinfo=UTC)
    if d2.tzinfo is None:
        d2 = d2.replace(tzinfo=UTC)

    return abs((d2 - d1).days)


def find_claude_md_files(root: Path) -> list[Path]:
    """Find all CLAUDE.md files, excluding certain directories."""
    results = []
    for claude_md in root.rglob("CLAUDE.md"):
        rel = claude_md.relative_to(root)
        parts_str = str(rel).replace("\\", "/")
        if any(parts_str.startswith(exc) for exc in EXCLUDE_DIRS):
            continue
        results.append(claude_md)
    return sorted(results)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate CLAUDE.md freshness")
    parser.add_argument("--ci", action="store_true", help="Exit 1 if stale files found")
    parser.add_argument("--threshold", type=int, default=14, help="Days before stale (default: 14)")
    args = parser.parse_args()

    root = Path(".")
    claude_files = find_claude_md_files(root)

    print(f"Checking {len(claude_files)} CLAUDE.md file(s) (stale threshold: {args.threshold} days)")
    print()

    fresh: list[str] = []
    stale: list[tuple[str, str, str, int]] = []
    unknown: list[str] = []

    for claude_md in claude_files:
        directory = claude_md.parent

        claude_date = get_git_date(str(claude_md))
        dir_date = get_dir_latest_date(directory)

        if not claude_date or not dir_date:
            unknown.append(str(claude_md))
            continue

        gap = days_between(claude_date, dir_date)

        if dir_date > claude_date and gap > args.threshold:
            stale.append((str(claude_md), claude_date[:10], dir_date[:10], gap))
        else:
            fresh.append(str(claude_md))

    if fresh:
        print(f"  Fresh: {len(fresh)} file(s)")

    if unknown:
        print(f"  Unknown (not in git): {len(unknown)} file(s)")
        for u in unknown:
            print(f"    ? {u}")

    if stale:
        print(f"  STALE: {len(stale)} file(s)")
        print()
        for path, c_date, d_date, gap in stale:
            print(f"    {path}")
            print(f"      CLAUDE.md last updated: {c_date}")
            print(f"      Directory last changed: {d_date} ({gap} days newer)")
            print()

    print(f"--- {len(fresh)} fresh, {len(stale)} stale, {len(unknown)} unknown ---")

    if args.ci and stale:
        print()
        print("STALE CLAUDE.md files detected. Update them to reflect current directory contents.")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
