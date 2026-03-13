# User Interaction Testing Skill

Patterns for testing user-facing interactions: input handling, menu navigation, and full user journeys. This skill covers how to write automated tests that simulate what a real user does.

## Why Interaction Testing Matters

Unit tests verify that individual functions return correct values. Interaction tests verify that the user can actually accomplish tasks through the UI. A system where every function passes unit tests can still be unusable if:

- Buttons don't respond to clicks
- Navigation flow skips a required screen
- Input is consumed by the wrong UI element
- State isn't properly carried between screens

## Input Injection Patterns

### Direct Action Injection

Most engines/frameworks provide a way to programmatically create and dispatch input events. Use this instead of relying on real hardware input during tests.

```
# Pseudocode — adapt to your engine/framework
func inject_action_press(action_name: String) -> void:
    var event = create_input_action(action_name, pressed=true)
    dispatch_input(event)
    process_frame()  # Let the engine handle the input

func inject_action_release(action_name: String) -> void:
    var event = create_input_action(action_name, pressed=false)
    dispatch_input(event)
    process_frame()
```

### Key Principles

1. **Always process a frame after injection** — the input event must propagate through the engine's input pipeline before assertions
2. **Pair press with release** — unless testing hold behavior, always release after pressing to avoid stuck-input state
3. **Clear input state between tests** — leftover pressed keys from a previous test will corrupt the next test
4. **Use action names, not raw keys** — test the abstraction layer the game uses, not hardware-specific bindings

### Continuous Input (Axes, Analog)

For analog input (steering, throttle), inject a value and hold it for multiple frames:

```
# Pseudocode
func inject_axis(action_negative: String, action_positive: String, value: float) -> void:
    if value > 0:
        set_action_strength(action_positive, abs(value))
        set_action_strength(action_negative, 0.0)
    else:
        set_action_strength(action_negative, abs(value))
        set_action_strength(action_positive, 0.0)
    process_frame()
```

### Mouse/Pointer Input

For UI testing, simulate mouse movement and clicks:

```
# Pseudocode
func click_at(position: Vector2) -> void:
    move_mouse_to(position)
    process_frame()
    inject_mouse_button(BUTTON_LEFT, pressed=true, position=position)
    process_frame()
    inject_mouse_button(BUTTON_LEFT, pressed=false, position=position)
    process_frame()

func click_control(control: UIElement) -> void:
    var center = control.global_position + control.size / 2
    click_at(center)
```

## Menu Flow Simulation

### Navigation Helper Pattern

Create a helper that knows how to navigate between screens:

```
# Pseudocode
class MenuNavigator:
    func navigate_to(target_screen: String) -> bool:
        # Define paths between known screens
        var paths = {
            "main_menu": ["splash"],           # from splash, go to main_menu
            "options": ["main_menu"],           # from main_menu, go to options
            "gameplay": ["main_menu", "mode_select", "pre_race"],
        }
        for intermediate in paths[target_screen]:
            if not _advance_from(intermediate):
                return false
        return _verify_screen(target_screen)

    func _advance_from(screen: String) -> bool:
        match screen:
            "splash":
                click_control(find_button("Start"))
                await_screen_transition()
                return true
            "main_menu":
                click_control(find_button("Play"))
                await_screen_transition()
                return true
        return false

    func _verify_screen(screen: String) -> bool:
        # Check that the expected screen is actually displayed
        return current_scene_name() == screen
```

### Screen Transition Verification

After every navigation action, verify:

1. **The old screen is gone** — it shouldn't still be processing input
2. **The new screen is present** — the expected UI elements exist
3. **Focus is correct** — the expected element has input focus (especially for gamepad navigation)
4. **State carried over** — any data from the previous screen is available (selected track, chosen car, etc.)

```
# Pseudocode
func assert_screen_transition(from: String, to: String) -> void:
    assert_false(is_screen_active(from), "Old screen '%s' still active" % from)
    assert_true(is_screen_active(to), "New screen '%s' not active" % to)
    assert_not_null(get_focused_control(), "No UI element has focus on '%s'" % to)
```

### Back Navigation

Test that every screen's back/cancel button returns to the correct parent:

```
# Pseudocode
func test_back_navigation():
    for screen in ["options", "mode_select", "leaderboard"]:
        navigate_to(screen)
        press_back()
        assert_screen("main_menu", "Back from %s should return to main_menu" % screen)
```

## User Journey Simulation

A user journey is a complete path through the application that accomplishes a real goal. Journeys test the full integration — not just individual screens.

### Journey Template

```
# Pseudocode
func test_journey_new_player_first_race():
    # Boot → Splash
    launch_application()
    assert_screen("splash")

    # Splash → Main Menu
    click_control(find_button("Start"))
    await_transition()
    assert_screen("main_menu")

    # Main Menu → Mode Select
    click_control(find_button("Play"))
    await_transition()
    assert_screen("mode_select")

    # Mode Select → Pre-Race Setup (default selections)
    click_control(find_button("Quick Race"))
    await_transition()
    assert_screen("pre_race_setup")

    # Pre-Race → Loading → Gameplay
    click_control(find_button("Start Race"))
    await_transition(timeout=10)  # Loading may take longer
    assert_screen("gameplay")

    # Verify gameplay state
    assert_true(race_is_active())
    assert_true(player_vehicle_exists())
    assert_equals(countdown_state(), "running")
```

### Critical Journeys to Test

Every application should have automated tests for these journeys at minimum:

| Journey | What It Tests |
|---------|--------------|
| **First launch** | Boot → initial setup → main screen |
| **Primary task** | The main thing users do (play a race, edit a document, etc.) |
| **Settings round-trip** | Change a setting → verify it takes effect → restart → verify it persisted |
| **Error recovery** | Trigger an error state → verify the user can recover without restarting |
| **Exit and resume** | Start a task → exit → restart → verify state is preserved |

## Edge Cases

### Rapid Input

Users press buttons faster than developers expect. Test:

```
# Pseudocode
func test_rapid_button_presses():
    navigate_to("main_menu")
    # Mash the play button 5 times quickly
    for i in range(5):
        click_control(find_button("Play"))
        # Do NOT wait for transition between clicks
    # Should end up on mode_select, not crash or double-navigate
    process_frames(30)  # Let everything settle
    assert_screen("mode_select")
```

### Simultaneous Inputs

Test conflicting inputs:

```
# Pseudocode
func test_simultaneous_throttle_and_brake():
    inject_action_press("throttle")
    inject_action_press("brake")
    process_frames(10)
    # Verify the game handles this gracefully
    # (behavior depends on design — brake priority, cancel out, etc.)
    assert_no_errors()
    inject_action_release("throttle")
    inject_action_release("brake")
```

### Unexpected Navigation

Test what happens when users go "off script":

| Scenario | Test |
|----------|------|
| Press back during loading | Should cancel gracefully, not crash |
| Open pause menu during countdown | Should pause the countdown or be blocked |
| Alt-tab during gameplay | Should auto-pause or continue without corruption |
| Resize window during menu | UI should adapt, not break layout |
| Disconnect controller during gameplay | Should pause or show reconnect prompt |

### Input During Transitions

Test input that arrives while a screen transition is animating:

```
# Pseudocode
func test_input_during_transition():
    click_control(find_button("Play"))
    # Immediately try to interact before transition completes
    inject_action_press("ui_cancel")
    process_frames(5)
    inject_action_release("ui_cancel")
    # Wait for transition to complete
    await_transition()
    # Verify we're in a sane state
    assert_true(is_on_valid_screen())
```

## Mocking External Systems

During user flow tests, external systems should be mocked to keep tests fast, deterministic, and isolated.

### What to Mock

| System | Why Mock | Mock Strategy |
|--------|----------|---------------|
| **Network** | Tests shouldn't depend on connectivity | Return canned responses for API calls |
| **File I/O** | Tests shouldn't write to real save files | Use in-memory storage or temp directory |
| **Platform services** | Steam, console APIs may not be available in CI | Stub that records calls without executing |
| **Audio** | Headless CI has no audio device | Null audio backend or silent stubs |
| **Time** | Tests need deterministic timing | Injectable clock that can be advanced manually |

### Mock Boundary Pattern

Mock at the boundary between your code and the external system, not deep inside your code:

```
# Good: mock the service interface
var mock_save_service = MockSaveService.new()
settings_manager.save_service = mock_save_service

# Bad: mock individual file operations inside the save code
# This couples your test to implementation details
```

## Verification: State Assertions After Each Step

After every interaction, assert the expected state change occurred. Don't just assert the final state — assert intermediate states too. This makes failures easier to diagnose.

### Assertion Patterns

```
# Pseudocode — after clicking "Start Race"

# Immediate: button should be disabled to prevent double-click
assert_false(start_button.is_enabled(), "Start button should disable after click")

# After transition: loading screen should be visible
await_transition()
assert_screen("loading")
assert_true(loading_bar.is_visible(), "Loading bar should be visible")

# After loading: gameplay should be active
await_condition(func(): return is_screen("gameplay"), timeout=10)
assert_true(race_manager.is_race_active(), "Race should be active after loading")
assert_not_null(player_vehicle, "Player vehicle should exist")
assert_equals(hud.lap_display.text, "Lap 1/3", "HUD should show starting lap")
```

### State Machine Verification

If your UI uses a state machine, verify state transitions:

```
# Pseudocode
func test_menu_state_machine():
    assert_state("idle")

    click_play()
    assert_state("transitioning")

    await_transition()
    assert_state("mode_select")

    click_back()
    assert_state("transitioning")

    await_transition()
    assert_state("idle")  # Back to main menu idle state
```

## Test Infrastructure Recommendations

### Helpers to Build

| Helper | Purpose |
|--------|---------|
| `InputInjector` | Inject actions, keys, mouse events with automatic cleanup |
| `MenuNavigator` | Navigate to any screen by name via shortest path |
| `ScreenAssertions` | Assert screen presence, focused element, visible controls |
| `JourneyRunner` | Execute a sequence of steps with assertions between each |
| `MockServiceProvider` | Swap real services for mocks before test, restore after |

### Test Isolation

Each test must start from a known state and leave no side effects:

1. **Setup:** Initialize to a known screen/state, connect mocks
2. **Execute:** Run the interaction sequence
3. **Assert:** Verify expected state
4. **Teardown:** Release injected inputs, restore real services, return to initial state

If a test fails mid-journey, the teardown must still run to avoid corrupting subsequent tests.
