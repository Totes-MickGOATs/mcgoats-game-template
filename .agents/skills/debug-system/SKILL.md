# Debug System Skill

How to build and use a debug overlay/logging system for development and diagnostics. This covers the Debug autoload pattern, F-key overlays, structured logging, and CI integration.

## Architecture: Debug Autoload

The debug system is a singleton (autoload) that manages all debug state, logging, and overlays. It is always available and safe to call from anywhere in the codebase.

### Core Responsibilities

| Responsibility | Description |
|----------------|-------------|
| **Structured logging** | Tagged, leveled log output with filtering |
| **Overlay management** | Toggle debug displays on/off with function keys |
| **Runtime inspection** | Read and display variable values in real-time |
| **Performance metrics** | FPS, frame time, memory usage |
| **CI integration** | Structured output for headless test environments |

### Design Principles

1. **Zero-cost when disabled** — debug checks should short-circuit immediately when the debug system is off
2. **Always safe to call** — `Debug.log()` must never crash, even if the debug system isn't initialized
3. **No gameplay impact** — debug overlays use `PROCESS_MODE_ALWAYS` and don't pause or alter game state
4. **Survives scene changes** — as an autoload, debug state persists across scene transitions

## Structured Logging

### The `Debug.log()` Pattern

All debug output goes through a single, consistent API:

```
Debug.log(tag: String, message: String)
```

**Tags** are short, lowercase identifiers for subsystems:

| Tag | Subsystem |
|-----|-----------|
| `physics` | Vehicle physics, collision |
| `ai` | AI behavior, pathfinding |
| `audio` | Sound playback, bus routing |
| `ui` | Menu flow, HUD updates |
| `net` | Networking, replication |
| `race` | Lap timing, checkpoints, positions |
| `input` | Input processing, bindings |
| `scene` | Scene loading, transitions |
| `save` | Settings persistence, save/load |
| `perf` | Performance warnings |

### Why Not Bare `print()`?

Bare `print()` statements cause problems:

1. **No filtering** — you can't turn off noisy subsystems without deleting the print
2. **No context** — "value is 3.5" doesn't tell you which system or why
3. **No levels** — you can't distinguish informational messages from warnings
4. **CI noise** — bare prints flood CI logs with unstructured output
5. **Forgotten prints** — they ship to production because nobody knows which are debug-only

The one exception: `@tool` scripts that run in the editor, where the Debug autoload isn't available.

### Log Levels

Support at least these levels:

| Level | When to Use | Example |
|-------|-------------|---------|
| **error** | Something is broken and needs immediate attention | `Debug.error("physics", "Wheel %d has no collision shape" % i)` |
| **warn** | Something unexpected that might cause issues | `Debug.warn("ai", "Racing line has 0 points, AI will not function")` |
| **info** | Normal operation, useful for tracing flow | `Debug.log("scene", "Loading track: %s" % track_name)` |
| **debug** | Verbose detail for active debugging | `Debug.debug("physics", "Wheel slip: %.3f" % slip)` |

### Filtering

The Debug autoload should support runtime filtering:

```
# Enable/disable tags
Debug.enable_tag("physics")
Debug.disable_tag("ai")

# Set minimum level
Debug.set_level("warn")  # Only warn and error

# Filter by pattern
Debug.set_filter("wheel")  # Only messages containing "wheel"
```

Filtering configuration can be:
- Set in code during initialization
- Toggled via debug console or overlay
- Configured in a debug config file (not shipped to production)
- Controlled by command-line arguments for CI

### Log Output Format

```
[0.234] [physics] Wheel 0 slip: lateral=0.12 longitudinal=0.05
[0.234] [physics] Wheel 1 slip: lateral=0.15 longitudinal=0.03
[1.567] [WARN] [ai] Racing line segment 12 has zero length
[2.891] [ERROR] [scene] Failed to load track: res://scenes/tracks/missing.tscn
```

Format: `[timestamp] [level?] [tag] message`

Timestamps help correlate events. Levels only appear for warn/error (info is the implicit default).

## F-Key Overlay System

Function keys toggle debug displays without interrupting gameplay. Each overlay is independent and can be enabled/disabled individually.

### Overlay Registry Pattern

```
# Pseudocode — adapt to your engine's input and scene system
var _overlays = {}

func register_overlay(key: int, name: String, overlay_template) -> void:
    _overlays[key] = {
        "name": name,
        "template": overlay_template,
        "instance": null,
        "visible": false
    }

func on_input(event) -> void:
    if is_key_press(event) and not is_key_repeat(event):
        if event.keycode in _overlays:
            toggle_overlay(event.keycode)

func toggle_overlay(key: int) -> void:
    var overlay = _overlays[key]
    if overlay.instance == null:
        overlay.instance = instantiate(overlay.template)
        add_to_scene(overlay.instance)
    overlay.visible = not overlay.visible
    overlay.instance.visible = overlay.visible
```

### Suggested Key Assignments

Reserve a block of function keys for debug overlays. Document them prominently:

| Key | Overlay | Description |
|-----|---------|-------------|
| F1 | Tuning Panel | Live parameter adjustment sliders |
| F2 | Performance | FPS, frame time, draw calls, memory |
| F3 | Physics | Collision shapes, contact points, forces |
| F4 | Graphics | Render mode cycling (wireframe, overdraw, etc.) |
| F5 | Camera | Debug camera modes, depth-of-field toggle |
| F6 | AI | Pathfinding lines, decision state, targets |
| F7 | Network | Ping, packet loss, replication state |
| F8 | Audio | Active buses, playing streams, volumes |
| F9 | Input | Raw input values, action states |
| F10 | Environment | Time-of-day, weather state, lighting |
| F11 | (Reserved) | Fullscreen toggle (OS convention) |
| F12 | (Reserved) | Screenshot (platform convention) |

### Overlay Design Guidelines

- **Transparent background** — don't obscure gameplay more than necessary
- **Fixed position** — top-left, top-right, or bottom of screen; don't overlap with game HUD
- **MOUSE_FILTER_IGNORE** — overlays must not capture mouse input
- **PROCESS_MODE_ALWAYS** — overlays work even when the game is paused
- **Color-coded values** — green for normal, yellow for warning, red for critical thresholds
- **Update rate** — don't update every frame if the overlay is text-heavy; 10-20 Hz is sufficient

## Performance Profiling Overlay

A dedicated overlay for real-time performance monitoring:

### Metrics to Display

| Metric | Source | Warning Threshold |
|--------|--------|-------------------|
| FPS | Engine FPS query (e.g., `Engine.get_frames_per_second()`) | < 55 (for 60Hz target) |
| Frame time | `1000.0 / fps` in ms | > 18ms |
| Physics ticks/sec | Count physics step calls per second | Deviation from target |
| Draw calls | Renderer statistics API | > project-specific threshold |
| Memory (static) | OS/engine memory query (e.g., `OS.get_static_memory_usage()`) | > 500 MB |
| Memory (dynamic) | OS/engine dynamic memory query | Rapid growth |
| Objects | Engine object count metric | > expected ceiling |
| Nodes/Entities | Engine entity count metric | > expected ceiling |

### Frame Time Graph

A rolling graph of frame times is more useful than an FPS counter alone. It reveals:
- **Spikes** — occasional hitches that average FPS masks
- **Patterns** — periodic spikes suggest GC, streaming, or timed operations
- **Trends** — gradually increasing frame time suggests a leak

```
# Pseudocode
var frame_times: Array = []
const MAX_SAMPLES = 300  # 5 seconds at 60fps

func on_frame_update(delta: float) -> void:
    frame_times.append(delta * 1000.0)
    if frame_times.size() > MAX_SAMPLES:
        frame_times.pop_front()
    # Draw as a line graph in the overlay
```

## Runtime Variable Inspection

### Watch List

Allow developers to "watch" specific variables at runtime:

```
# Pseudocode — in any script
Debug.watch("player_speed", player.velocity.length())
Debug.watch("wheel_0_slip", wheel.slip_ratio)
Debug.watch("ai_state", ai.current_state_name)

# In the Debug overlay — displays all watched values
# player_speed:  45.2
# wheel_0_slip:   0.13
# ai_state:      BRAKING
```

### Property Inspector

For deeper inspection, allow drilling into object properties:

```
# Pseudocode
Debug.inspect(vehicle)
# Opens a panel showing all exported properties and their current values
# Values update in real-time
```

### Visual Debug Drawing

For spatial debugging (3D positions, vectors, areas):

```
# Pseudocode
Debug.draw_line(from, to, color, duration)
Debug.draw_sphere(position, radius, color, duration)
Debug.draw_ray(origin, direction, length, color, duration)
Debug.draw_label_3d(position, text, color)

# These persist for `duration` seconds, then auto-remove
# When the debug system is off, these are no-ops
```

## Integration with CI (Headless Mode)

### Challenges

- No display — overlays can't render
- No input — F-keys aren't available
- Limited logging — CI logs have size limits
- Different environment — paths, permissions, available hardware differ

### CI Mode Behavior

The Debug autoload should detect headless/CI mode and adapt:

```
# Pseudocode
var is_ci: bool = is_headless_mode() or get_env("CI") != ""

func on_ready() -> void:
    if is_ci:
        # Disable visual overlays
        # Enable structured log output (machine-parseable)
        # Set log level from environment variable
        set_level(get_env("DEBUG_LEVEL") or "warn")
```

### Structured CI Output

In CI mode, emit logs in a parseable format:

```
# Standard format for CI log parsing
::debug::tag=physics::Wheel 0 grounded: true
::warning::tag=ai::Racing line has 0 speed hints
::error::tag=scene::Track failed to load: missing.tscn
```

Many CI systems (GitHub Actions, GitLab CI) support `::warning::` and `::error::` annotations that surface in the UI.

### Test Integration

Tests can interact with the Debug system:

```
# Pseudocode — in a test
func test_physics_logging():
    Debug.clear_log()
    Debug.enable_tag("physics")
    Debug.set_level("debug")

    # Run the code under test
    vehicle.physics_step(delta)

    # Verify expected debug output
    var logs = Debug.get_log_entries("physics")
    assert_true(logs.size() > 0, "Physics should produce debug output")
    assert_true(logs.any(func(e): return "slip" in e.message), "Should log slip values")
```

## Implementation Checklist

When building a debug system for a new project:

- [ ] Debug autoload registered in project settings
- [ ] `Debug.log(tag, message)` API implemented with level filtering
- [ ] Tag enable/disable support
- [ ] F-key overlay registry
- [ ] Performance overlay (FPS, frame time, memory)
- [ ] `Debug.watch()` variable display
- [ ] Visual debug drawing (lines, spheres, labels)
- [ ] CI/headless mode detection with adapted output
- [ ] Zero-cost when disabled (early return checks)
- [ ] Documentation of F-key assignments visible in-game or in project docs
- [ ] No bare `print()` calls in non-tool scripts (enforced by lint rule or code review)
