# E2E Testing Guide

## What is E2E Testing?

End-to-end (E2E) testing verifies full user journeys -- boot the game, navigate menus, enter gameplay, interact with systems, and verify state. Unlike unit tests (isolated logic) or integration tests (a few systems together), E2E tests exercise the entire game stack as a player would experience it.

E2E tests answer: "Does the game actually work when everything is wired together?"

## Why E2E Tests Matter

- Unit tests can pass while the game is broken (wiring issues, missing signals, wrong scene setup)
- Integration tests cover pairs of systems but miss emergent failures from the full chain
- E2E tests catch the class of bugs that only appear when the full game is running: scene transitions that leak nodes, input that stops working after a pause, state that doesn't persist across loads

## Architecture

### E2E Test Base Class

The foundation is a base class that provides:

- **Step tracking** -- named steps within a test for clear failure reporting
- **Assertion helpers** -- `assert_true`, `assert_eq`, `assert_gt`, `assert_lt`, `assert_not_null` that log PASS/FAIL with context
- **Timeout-guarded waits** -- `wait_for_state`, `wait_until`, `wait_for_signal`, `wait_seconds`, `wait_frames`
- **Input injection** -- `press_action`, `release_action`, `hold_action`, `tap_action` to simulate player input
- **Game state helpers** -- `setup_gameplay` (skip menus for focused tests), `find_player`, leak detection counters

The base class extends a lightweight type (e.g., `RefCounted` in Godot, `ScriptableObject` in Unity) -- it does NOT need to be a scene node. It receives a reference to the scene tree/game context for async operations.

```
# Pseudocode -- adapt to your engine's language
class E2ETest:
    var test_name: String
    var passed: bool  # true if no failures and no abort

    # Step tracking
    func step(name)      # Mark a named step
    func abort(reason)   # Abort test early

    # Assertions (return bool so tests can early-exit on failure)
    func assert_true(condition, msg) -> bool
    func assert_eq(actual, expected, msg) -> bool
    func assert_gt(actual, threshold, msg) -> bool
    func assert_lt(actual, threshold, msg) -> bool
    func assert_not_null(value, msg) -> bool

    # Async waits (all with timeout to prevent hangs)
    func wait_seconds(n)
    func wait_frames(n)
    func wait_for_state(target_state, timeout) -> bool
    func wait_until(condition_callable, timeout) -> bool
    func wait_for_signal(object, signal_name, timeout) -> bool

    # Input injection
    func press_action(action_name)
    func release_action(action_name)
    func hold_action(action_name, duration)
    func tap_action(action_name)

    # Game state
    func setup_gameplay(config) -> bool  # Skip menus, load gameplay directly
    func find_player() -> Object         # Locate player entity
    func get_node_count() -> int         # For leak detection
    func get_orphan_count() -> int       # For leak detection

    # Override in subclasses
    func run()  # Async -- contains the test steps
```

### E2E Runner

The runner is a lightweight node/object that:

1. Discovers test files by naming convention (e.g., `tests/e2e/test_*.gd`)
2. Instantiates each test class
3. Calls `run()` on each test sequentially (async)
4. Collects results (pass/fail/abort per test)
5. Prints a summary with consistent tags for monitoring

The runner is activated by a CLI flag (e.g., `--e2e-test=all` or `--e2e-test=boot_to_gameplay`). The game's boot script checks for this flag and adds the runner to the scene tree.

### Logging Convention

All E2E output uses consistent tags for automated monitoring:

```
[E2E] --- Running: boot_to_gameplay ---
[E2E]   [STEP] Wait for main menu
[E2E]     [PASS] Reached main menu
[E2E]   [STEP] Navigate to gameplay
[E2E]     [PASS] Entered gameplay
[E2E]     [FAIL] Player health (expected > 0, actual = 0)
[E2E] --- boot_to_gameplay: FAIL ---
[E2E] === E2E SUMMARY ===
[E2E] Passed: 3/4, Failed: 1
```

## Common Test Patterns

### Boot to Gameplay

Verifies the full startup chain works:

```
class BootToGameplayTest extends E2ETest:
    func run():
        step("Boot sequence")
        var ok = await wait_for_state(MAIN_MENU, 15.0)
        if not assert_true(ok, "Reached main menu"):
            abort("Never reached main menu")
            return

        step("Start game")
        tap_action("ui_accept")
        ok = await wait_for_state(GAMEPLAY, 30.0)
        if not assert_true(ok, "Entered gameplay"):
            abort("Never entered gameplay")
            return

        step("Verify player")
        var player = find_player()
        assert_not_null(player, "Player spawned")

        step("Return to menu")
        tap_action("pause")
        tap_action("quit_to_menu")
        ok = await wait_for_state(MAIN_MENU, 10.0)
        assert_true(ok, "Returned to menu cleanly")
```

**What it catches:** Missing autoloads, broken scene references, initialization order bugs, scene transition failures.

### Menu Navigation

Verifies all menu paths are reachable:

```
class MenuNavigationTest extends E2ETest:
    func run():
        step("Reach main menu")
        await wait_for_state(MAIN_MENU, 15.0)

        step("Open options")
        tap_action("options_button")
        await wait_seconds(0.5)
        assert_true(is_screen_visible("options"), "Options screen shown")

        step("Back to main menu")
        tap_action("ui_cancel")
        await wait_seconds(0.5)
        assert_true(is_screen_visible("main_menu"), "Back at main menu")

        # Repeat for all menu paths...
```

**What it catches:** Dead-end screens, broken back navigation, missing button connections, screens that don't clean up.

### State Persistence

Verifies save/load roundtrip:

```
class StatePersistenceTest extends E2ETest:
    func run():
        step("Set a value")
        # Change a setting or game state
        set_test_setting("audio_volume", 0.5)
        save_settings()

        step("Reload")
        reload_settings()

        step("Verify persisted")
        var vol = get_test_setting("audio_volume")
        assert_eq(vol, 0.5, "Volume persisted")
```

**What it catches:** Serialization bugs, missing save calls, load-order dependencies, type coercion errors.

### Scene Leak Detection

Verifies scene transitions don't leak objects:

```
class SceneLeakTest extends E2ETest:
    func run():
        step("Baseline node count")
        await wait_for_state(MAIN_MENU, 15.0)
        var baseline = get_node_count()
        var orphan_baseline = get_orphan_count()

        step("Transition cycle")
        # Go to gameplay and back, multiple times
        for i in range(3):
            await setup_gameplay(default_config)
            await wait_seconds(2.0)
            tap_action("pause")
            tap_action("quit_to_menu")
            await wait_for_state(MAIN_MENU, 10.0)
            await wait_seconds(1.0)

        step("Check for leaks")
        var final_count = get_node_count()
        var orphan_final = get_orphan_count()
        var delta = final_count - baseline
        var orphan_delta = orphan_final - orphan_baseline

        # Allow small variance (timers, async cleanup)
        assert_lt(float(delta), 50.0, "Node count delta after 3 cycles")
        assert_lt(float(orphan_delta), 10.0, "Orphan count delta after 3 cycles")
```

**What it catches:** Nodes not freed on scene exit, signal connections preventing garbage collection, orphaned nodes from `remove_child` without `queue_free`.

### Pause/Resume

Verifies pause behavior:

```
class PauseStateTest extends E2ETest:
    func run():
        step("Enter gameplay")
        await setup_gameplay(default_config)
        var player = find_player()

        step("Record pre-pause state")
        var pos_before = player.position
        var score_before = get_score()

        step("Pause")
        tap_action("pause")
        await wait_seconds(2.0)  # Wait while paused

        step("Verify frozen")
        assert_eq(player.position, pos_before, "Position unchanged while paused")
        assert_eq(get_score(), score_before, "Score unchanged while paused")

        step("Unpause")
        tap_action("pause")
        await wait_seconds(0.5)

        step("Verify resumed")
        # Player should be able to move now
        hold_action("move_forward", 1.0)
        assert_true(player.position != pos_before, "Player moved after unpause")
```

**What it catches:** Process mode errors (systems running while paused), input routing bugs, state corruption on resume.

## Writing E2E Tests

### Step-by-step guide

1. **Create the test file** in `tests/e2e/test_<name>.<ext>`
2. **Extend the E2E base class** and set the test name in the constructor
3. **Implement `run()`** as an async method with sequential steps
4. **Use `step()` to name each phase** -- this is what appears in failure reports
5. **Use `assert_*` for verification** -- they return `bool` so you can early-exit on critical failures
6. **Use `wait_*` for async operations** -- ALWAYS with a timeout
7. **Use `abort()` for unrecoverable failures** -- skips remaining steps

### Best practices

- **Early exit on critical failures:** If a step fails that makes later steps meaningless (e.g., gameplay didn't load), call `abort()` and return. Don't let the test stumble through 10 more assertions that will all fail for the same root cause.
- **Use setup_gameplay() for focused tests:** If you're testing pause behavior, skip the menus and load gameplay directly. Only test menu navigation in the menu navigation test.
- **Keep tests independent:** Each test should start from a clean state. Don't rely on another test having run first.
- **Timeout generously but not infinitely:** Scene loads might take 10-30 seconds. A 5-second timeout will cause flaky failures. But don't use 300-second timeouts that hide real hangs.
- **Test the unhappy path too:** What happens when the player does something unexpected? Pause during a loading screen? Spam the back button?

## Running E2E Tests

```
# ENGINE-SPECIFIC: Replace with your engine's run command

# Run all E2E tests
<engine_command> -- --e2e-test=all

# Run a specific test
<engine_command> -- --e2e-test=boot_to_gameplay

# Run tests matching a filter
<engine_command> -- --e2e-test=pause
```

The boot script should check for the `--e2e-test` CLI argument and, if present, add the E2E runner to the scene tree instead of (or in addition to) normal boot flow.

## Monitoring E2E Runs

When running E2E tests (especially via the `/dev:e2e-test` command):

1. **Poll debug output** every 3-5 seconds
2. **Watch for `[E2E]` tagged lines** -- especially `[FAIL]` and `[ABORT]`
3. **Capture screenshots** at failures for visual debugging
4. **Watch for non-E2E errors** -- game errors during E2E runs are bugs too
5. **Wait for `=== E2E SUMMARY ===`** to know all tests are complete

## Relationship to Other Test Types

| Aspect | Unit Tests | Integration Tests | E2E Tests |
|--------|-----------|-------------------|-----------|
| **Scope** | Single function/class | 2-3 systems together | Full game |
| **Speed** | Milliseconds | Seconds | 10-60 seconds per test |
| **Dependencies** | Mocked | Partially real | All real |
| **When to write** | Always | When wiring matters | Key user journeys |
| **Failure diagnosis** | Pinpoints exact function | Narrows to system boundary | "Something is broken in this flow" |
| **Maintenance cost** | Low | Medium | High (brittle to UI changes) |

E2E tests are the most expensive to write and maintain, so focus them on critical paths: boot-to-gameplay, save/load, and any flow that has historically broken.
