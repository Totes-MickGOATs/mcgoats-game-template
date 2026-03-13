---
description: Multi-phase quality checklist — run before marking any task as done
---

# Bulletproof Quality Checklist

Run through ALL six phases. Every phase must PASS before the task is complete. If any check fails, fix it before proceeding. Do not skip phases.

---

## Phase 0: Pre-flight

Verify the workspace is clean and you are on the correct branch.

- [ ] **Branch check:** `git branch --show-current` shows `feat/<task>` (NOT `main`)
- [ ] **No uncommitted changes:** `git status` shows clean working tree (or only intentional unstaged files)
- [ ] **Lint passes:** Run the project linter and confirm zero errors
  ```bash
  just python-lint
  ```
  <!-- ENGINE-SPECIFIC: Engine lint command added by setup-engine.sh -->
- [ ] **Registry valid:** `just validate-registry` passes with no errors

**PASS criteria:** On feature branch, clean tree, lint green, registry valid.

---

## Phase 1: Code Quality

Review every changed file for quality issues.

```bash
git diff origin/main...HEAD --name-only
```

For each changed file, verify:

- [ ] **No magic numbers** — all numeric literals that represent domain concepts use named constants
- [ ] **Naming is clear** — variables, functions, classes use descriptive names; no single-letter names outside loop counters
- [ ] **Type safety** — function signatures have type annotations; return types declared
- [ ] **Error handling** — system boundaries (file I/O, network, parsing) have error handling
- [ ] **No hardcoded paths** — file paths, URLs, credentials use configuration or constants
- [ ] **DRY compliance** — no duplicated logic blocks; if 3+ instances of a pattern exist, a helper is extracted
- [ ] **Single responsibility** — each function/class does one thing; functions under 50 lines preferred
- [ ] **No dead code** — removed unused imports, commented-out blocks, unreachable branches

**PASS criteria:** All changed files pass all checks above.

---

## Phase 2: Testing

Verify TDD compliance and test coverage.

- [ ] **Tests exist** for every new or changed function/class
- [ ] **TDD cycle followed** — tests were written BEFORE implementation (red-green-commit)
- [ ] **Unit tests** cover isolated logic (math, parsing, state transitions)
- [ ] **Integration tests** cover system wiring (signals, cross-system interaction) where applicable
- [ ] **Edge cases** covered — null/empty inputs, boundary values, error paths
- [ ] **Tests actually run** — execute the test files and confirm GREEN
  <!-- ENGINE-SPECIFIC: Test runner command added by setup-engine.sh -->
- [ ] **No test-only hacks** — production code was not modified solely to make tests pass in an unnatural way

**PASS criteria:** All relevant tests exist, run, and pass. TDD cycle was followed.

---

## Phase 3: Documentation

Verify documentation is current.

- [ ] **CLAUDE.md updated** — every directory with changed files has an up-to-date `CLAUDE.md`
  - New files added to file listings
  - Removed files deleted from listings (no "removed" comments left behind)
  - Descriptions accurate for changed files
- [ ] **Manifest entries** — new system files added to appropriate `resources/manifests/` manifest
- [ ] **Skill references** — if a new skill area was created, `.agents/skills/<name>/SKILL.md` exists and is referenced
- [ ] **Commit messages** — all commits use conventional format: `type: short description`
- [ ] **No stale references** — no imports, references, or docs pointing to deleted files

**PASS criteria:** Documentation matches code reality. No stale references.

---

## Phase 4: Contract Sync

Verify that interfaces between systems are consistent.

- [ ] **Signal/event names match** — emitter signal names match receiver handler names exactly
- [ ] **API consistency** — function signatures match all call sites (parameter count, types, order)
- [ ] **Configuration keys** — settings keys used in code match keys in config files/schemas
- [ ] **Constants in sync** — if a constant is mirrored in tests, both values match
- [ ] **Cross-system contracts** — if System A expects System B to provide data in a certain format, verify B does so
- [ ] **No broken wiring** — signals connected in scene/code are actually emitted; handlers exist for all connected signals

**PASS criteria:** All cross-system interfaces are consistent. No mismatched names, types, or contracts.

> **Contract sync failures are MUST FIX.** A passing unit test with a broken contract means the feature will fail at runtime.

---

## Phase 5: Final Verification

Last checks before pushing.

- [ ] **Local tests pass** — run all test files related to your changes one final time
- [ ] **No uncommitted changes** — `git status` is clean
- [ ] **All files committed** — no "forgot to add" files lurking
- [ ] **Branch is fresh** — rebase onto latest `origin/main` if commits have landed:
  ```bash
  git fetch origin && git rebase origin/main
  ```
- [ ] **Push and verify CI:**
  ```bash
  git push
  gh run watch
  ```
- [ ] **Auto-merge enabled:**
  ```bash
  gh pr merge --auto --squash
  ```

**PASS criteria:** CI green, auto-merge enabled, branch up to date with main.

---

## Summary

| Phase | Focus | Key Question |
|-------|-------|-------------|
| 0 | Pre-flight | Am I on the right branch with a clean workspace? |
| 1 | Code quality | Is the code clean, DRY, and well-named? |
| 2 | Testing | Are there tests, do they run, do they pass? |
| 3 | Documentation | Does the documentation match the code? |
| 4 | Contract sync | Do systems agree on their interfaces? |
| 5 | Final verification | Is everything pushed and CI green? |

All six phases must pass. If any phase fails, fix the issue and re-verify that phase before proceeding.
