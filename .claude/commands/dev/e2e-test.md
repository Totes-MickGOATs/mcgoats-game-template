---
description: Run end-to-end tests that exercise full user journeys through the live game
---

Run end-to-end tests that exercise full user journeys through the live game.

## What Are E2E Tests?

E2E (end-to-end) tests run inside the actual game process with real systems -- real physics, real scene transitions, real input handling. They verify that the full chain works, not just individual units.

Unlike unit tests (isolated, mocked) or integration tests (a few systems together), E2E tests simulate what a player actually does: boot the game, navigate menus, enter gameplay, interact, and exit.

## Design Principles

1. **Real scene tree** -- tests run in the actual game, not a mock environment
2. **Full user journeys** -- start from boot, traverse menus, enter gameplay, verify outcomes
3. **Async by nature** -- scene transitions, loading screens, and physics all take real time
4. **Step-based structure** -- each test is a sequence of named steps for clear failure reporting
5. **Non-destructive** -- tests should not corrupt save data or settings (use test profiles/configs)
6. **Timeout-guarded** -- every wait operation has a timeout to prevent infinite hangs

## Setup

1. **Launch the game** with E2E test flags. The exact command depends on your engine:
   ```
   # ENGINE-SPECIFIC: Replace with your engine's run command
   # Example: godot --main-pack game.pck -- --e2e-test=all
   # Example: unity -executeMethod E2ERunner.Run -filter boot_to_gameplay
   <engine_run_command> --e2e-test=<filter>
   ```

2. **Available filters** (adapt to your test suite):
   - `all` -- run all E2E tests
   - `boot_to_gameplay` -- full boot -> menu -> gameplay flow
   - `menu_navigation` -- verify all menu paths are reachable
   - `state_persistence` -- save/load roundtrip verification
   - `scene_leak` -- scene transitions don't leak nodes/objects

3. **Announce** to the user which tests will run.

## Test Structure Template

Each E2E test follows this pattern:

```
class BootToGameplayTest extends E2ETest:
    func run():
        step("Wait for boot sequence")
        # Wait for the game to finish its startup chain
        ok = wait_for_state(MAIN_MENU, timeout=15.0)
        assert_true(ok, "Reached main menu")

        step("Navigate to gameplay")
        # Simulate menu navigation to start a game session
        tap_action("ui_accept")  # Start game
        ok = wait_for_state(GAMEPLAY, timeout=30.0)
        assert_true(ok, "Entered gameplay")

        step("Verify gameplay state")
        player = find_player()
        assert_not_null(player, "Player exists")
        assert_gt(player.health, 0, "Player is alive")

        step("Return to menu")
        tap_action("pause")
        tap_action("quit_to_menu")
        ok = wait_for_state(MAIN_MENU, timeout=10.0)
        assert_true(ok, "Returned to main menu")
```

## Common E2E Patterns

### Boot to Gameplay
Verify the full startup chain works end-to-end:
- Game boots without errors
- Splash/loading screens complete
- Main menu is interactive
- Starting a game session loads correctly
- Player can control their character/vehicle

### Menu Navigation
Verify all menu paths are reachable and functional:
- Every button leads to the expected screen
- Back/cancel returns to the previous screen
- Settings changes persist through menu transitions
- No dead-end screens

### State Persistence
Verify save/load roundtrip:
- Save game state (settings, progress, etc.)
- Restart or reload
- Verify saved state was restored correctly
- Check edge cases: first launch (no save file), corrupted save

### Scene Leak Detection
Verify scene transitions don't leak objects:
- Record node/object count before transition
- Transition to a new scene and back
- Compare counts -- delta should be zero or very small
- Repeat multiple times to detect gradual leaks
- Check for orphan nodes/objects specifically

### Pause/Resume
Verify pause behavior:
- Pause freezes gameplay (position, physics, timers)
- UI remains responsive while paused
- Resume restores exact state
- Input is correctly routed (gameplay input blocked while paused)

## E2E Test Base Class API

Your E2E test base class should provide these helpers:

### Step Tracking
- `step(name)` -- mark a named test step (for failure reporting)
- `abort(reason)` -- abort the current test early

### Assertions
- `assert_true(condition, msg)` -- check boolean condition
- `assert_eq(actual, expected, msg)` -- equality check
- `assert_gt(actual, threshold, msg)` -- greater-than check
- `assert_lt(actual, threshold, msg)` -- less-than check
- `assert_not_null(value, msg)` -- null check

### Wait Helpers (Async)
- `wait_seconds(n)` -- wait real time
- `wait_frames(n)` -- wait N frames
- `wait_for_state(state, timeout)` -- wait for game state transition
- `wait_until(condition, timeout)` -- poll condition each frame
- `wait_for_signal(obj, signal_name, timeout)` -- wait for a signal

### Input Injection
- `press_action(action)` -- simulate input press
- `release_action(action)` -- simulate input release
- `hold_action(action, duration)` -- press, wait, release
- `tap_action(action)` -- quick press and release

### Game State
- `setup_gameplay(config)` -- skip menus, load gameplay directly (for focused tests)
- `find_player()` -- locate the player entity
- `get_node_count()` -- for leak detection
- `get_orphan_count()` -- for leak detection

## Monitoring Loop

While E2E tests run:

1. **Poll debug output** every 3-5 seconds
2. **Watch for tagged log lines** -- E2E output should use consistent tags:
   - `[STEP]` -- test step starting
   - `[PASS]` -- assertion passed
   - `[FAIL]` -- assertion failed (highlight these)
   - `[ABORT]` -- test aborted early
3. **Capture screenshots** at key moments (test start, failures, completion)
4. **Watch for non-E2E errors** -- game errors during E2E runs are bugs too

## When Tests Complete

Produce a report:

### E2E Test Report

**Tests Run**: [count]
**Passed**: [count]
**Failed**: [count]

**Results**:
| Test | Status | Steps Completed | Notes |
|------|--------|-----------------|-------|
| boot_to_gameplay | PASS/FAIL | 8/10 | ... |

**Failures** (if any):
- Test: [name], Step: [step], Assertion: [what failed]
- Suggested fix: [based on the failure context]

**Errors Outside E2E** (game errors detected during test run):
- [list any non-E2E errors from debug output]

## Writing New E2E Tests

1. Create a test file in the E2E test directory (e.g., `tests/e2e/test_<name>.<ext>`)
2. Extend the E2E test base class
3. Implement `run()` with sequential steps
4. Use `step()` to name each phase for clear failure reporting
5. Use `assert_*` helpers for verification (they log PASS/FAIL automatically)
6. Use `wait_*` helpers for async operations (always with timeouts)
7. Register the test with the E2E runner (or use auto-discovery via naming convention)

## Verification Points (Every E2E Test Should Check)

- No crashes or unhandled exceptions during the entire flow
- No leaked nodes/objects after scene transitions
- Correct state transitions (game state machine follows expected path)
- Player input is responsive after every transition
- UI elements are visible and interactive when expected
- No NaN or infinite values in gameplay state (positions, scores, timers)
