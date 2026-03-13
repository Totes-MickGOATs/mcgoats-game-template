#!/usr/bin/env python3
"""Test coverage report — tracks tested vs untested game systems.

No addons needed. Counts production scripts vs test files and reports
per-category coverage using the tiered approach.

Modes:
  (default)       Human-readable report to stdout
  --json          Machine-readable JSON to stdout
  --ci            CI mode: compare against baseline, fail on regression
  --save-baseline Write current snapshot to .coverage-baseline.json
"""

from __future__ import annotations

import argparse
import io
import json
import sys
from pathlib import Path

# Force UTF-8 output on Windows
if sys.stdout and hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

PROJECT = Path(__file__).resolve().parent.parent.parent
TESTS_DIR = PROJECT / "tests"
BASELINE_FILE = PROJECT / ".coverage-baseline.json"

# ── System categories with target ranges ──────────────────────────────────────
# Customize this for your project. Add your game systems here.
CATEGORIES: dict[str, dict] = {
    "Example systems": {
        "target": (50, 70),
        "scripts": {
            # "system_name": "path/to/system.gd",
        },
    },
}


def find_test_file(system_name: str) -> Path | None:
    """Look for a test file matching the system name."""
    # Try common patterns across engines
    for prefix in ("test_", "Test"):
        for ext in (".gd", ".cs", ".cpp"):
            candidate = TESTS_DIR / f"{prefix}{system_name}{ext}"
            if candidate.exists():
                return candidate
    # Fuzzy match
    for test_file in TESTS_DIR.glob("test_*.*"):
        if system_name in test_file.stem.removeprefix("test_"):
            return test_file
    return None


def count_test_methods(test_file: Path) -> int:
    """Count test methods in a test file."""
    count = 0
    text = test_file.read_text(encoding="utf-8")
    for line in text.splitlines():
        stripped = line.strip()
        # GDScript: func test_
        if stripped.startswith("func test_"):
            count += 1
        # C#: [Test] or [TestMethod] followed by public void
        elif stripped.startswith("public void Test") or stripped.startswith("public async Task Test"):
            count += 1
        # C++: TEST_F or TEST
        elif stripped.startswith("TEST(") or stripped.startswith("TEST_F("):
            count += 1
    return count


def gather_snapshot() -> dict:
    """Build a coverage snapshot."""
    categories = {}
    total_scripts = 0
    total_tested = 0
    total_tests = 0

    for category, data in CATEGORIES.items():
        target_lo, target_hi = data["target"]
        scripts = data["scripts"]
        tested = 0
        cat_tests = 0
        systems = {}

        for name in scripts:
            test_file = find_test_file(name)
            if test_file:
                n = count_test_methods(test_file)
                systems[name] = {"tested": True, "test_file": test_file.name, "test_count": n}
                tested += 1
                cat_tests += n
            else:
                systems[name] = {"tested": False, "test_file": None, "test_count": 0}

        pct = (tested / len(scripts) * 100) if scripts else 0
        categories[category] = {
            "tested": tested,
            "total": len(scripts),
            "pct": round(pct, 1),
            "target_lo": target_lo,
            "target_hi": target_hi,
            "passing": pct >= target_lo,
            "test_count": cat_tests,
            "systems": systems,
        }
        total_scripts += len(scripts)
        total_tested += tested
        total_tests += cat_tests

    return {
        "categories": categories,
        "overall_tested": total_tested,
        "overall_total": total_scripts,
        "overall_pct": round((total_tested / total_scripts * 100) if total_scripts else 0, 1),
        "total_test_methods": total_tests,
    }


def print_report(snap: dict) -> bool:
    """Print human-readable report. Returns True if all targets met."""
    all_pass = True
    print("=" * 72)
    print("TEST COVERAGE REPORT")
    print("=" * 72)

    for cat_name, cat in snap["categories"].items():
        status = "OK" if cat["passing"] else "BELOW TARGET"
        marker = "  " if cat["passing"] else "!! "
        print(f"\n{marker}{cat_name} -- {cat['tested']}/{cat['total']} ({cat['pct']:.0f}%) "
              f"[target: {cat['target_lo']}-{cat['target_hi']}%] [{status}]")
        for name, info in cat["systems"].items():
            if info["tested"]:
                print(f"    {name:30s} + {info['test_file']} ({info['test_count']} tests)")
            else:
                print(f"    {name:30s} - NO TESTS")
        if not cat["passing"]:
            all_pass = False

    print("\n" + "=" * 72)
    print(f"OVERALL: {snap['overall_tested']}/{snap['overall_total']} "
          f"systems tested ({snap['overall_pct']:.0f}%)")
    print(f"TOTAL:   {snap['total_test_methods']} test methods")
    print("=" * 72)

    return all_pass


def save_baseline(snap: dict) -> None:
    """Save snapshot as the coverage baseline."""
    BASELINE_FILE.write_text(json.dumps(snap, indent=2, default=str), encoding="utf-8")
    print(f"Baseline saved to {BASELINE_FILE}")


def ci_compare(snap: dict) -> int:
    """Compare against baseline. Fail on regression."""
    if not BASELINE_FILE.exists():
        print("No baseline found. Saving current snapshot as baseline.")
        save_baseline(snap)
        print_report(snap)
        return 0

    baseline = json.loads(BASELINE_FILE.read_text(encoding="utf-8"))
    all_pass = print_report(snap)

    regressions: list[str] = []
    improvements: list[str] = []

    prev_cats = baseline.get("categories", {})
    for cat_name, cat in snap["categories"].items():
        prev = prev_cats.get(cat_name, {})
        prev_tested = prev.get("tested", 0)
        if cat["tested"] < prev_tested:
            regressions.append(f"{cat_name}: coverage dropped {prev_tested} -> {cat['tested']}")
        elif cat["tested"] > prev_tested:
            improvements.append(f"{cat_name}: coverage improved {prev_tested} -> {cat['tested']}")

    print("\n--- COVERAGE DELTA (vs baseline) ---")
    if improvements:
        for imp in improvements:
            print(f"  + {imp}")
    if regressions:
        print("\n!! REGRESSIONS:")
        for reg in regressions:
            print(f"::error::Coverage regression: {reg}")
            print(f"  !! {reg}")
        return 1

    if improvements:
        save_baseline(snap)
        print("Baseline auto-updated with improvements.")

    print("\n+ No regressions detected.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Test coverage report")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--ci", action="store_true", help="CI mode: compare vs baseline")
    parser.add_argument("--save-baseline", action="store_true", help="Save current as baseline")
    args = parser.parse_args()

    snap = gather_snapshot()

    if args.save_baseline:
        save_baseline(snap)
        print_report(snap)
        return 0
    if args.json:
        print(json.dumps(snap, indent=2, default=str))
        return 0
    if args.ci:
        return ci_compare(snap)

    all_pass = print_report(snap)
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
