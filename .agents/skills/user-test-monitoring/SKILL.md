# User Test Monitoring Skill

How to set up, run, and analyze user testing sessions. This covers recording player behavior, capturing performance and error data, and turning raw session data into actionable insights.

## Purpose

User testing reveals problems that automated tests cannot: confusing UI, unexpected player behavior, performance issues on real hardware, and friction points in the experience. Monitoring infrastructure captures this data so you can analyze it after the session instead of relying on memory or notes.

## Test Session Setup

### Recording Infrastructure

Before a test session, ensure these systems are active:

| System | What It Captures | Storage |
|--------|-----------------|---------|
| **Input recorder** | Every player input with timestamps | `user://sessions/<id>/inputs.dat` |
| **State snapshotter** | Periodic game state dumps (position, health, inventory, etc.) | `user://sessions/<id>/state.dat` |
| **Event logger** | Discrete game events (level complete, death, menu open, etc.) | `user://sessions/<id>/events.log` |
| **Performance monitor** | FPS, frame time, memory at regular intervals | `user://sessions/<id>/perf.csv` |
| **Error capture** | Crashes, exceptions, warnings | `user://sessions/<id>/errors.log` |
| **Screen recorder** | Video of gameplay (optional, external tool) | Separate file |

### Session Metadata

Each session should record:

```
# Pseudocode — session_info.json
{
    "session_id": "2026-03-13_001",
    "timestamp": "2026-03-13T14:30:00Z",
    "build_version": "0.5.2-beta",
    "build_hash": "abc1234",
    "platform": "windows",
    "hardware": {
        "gpu": "RTX 4070",
        "cpu": "i7-13700K",
        "ram_gb": 32,
        "display": "2560x1440@144Hz"
    },
    "tester": "anonymous_01",  // or name if consented
    "session_type": "guided",  // or "freeplay"
    "notes": ""
}
```

### Pre-Session Checklist

- [ ] Recording systems enabled and verified (check a few seconds of output)
- [ ] Build version tagged — you need to know exactly what code the tester is running
- [ ] Save files cleared or set to a known state (depending on what you're testing)
- [ ] Test scenario documented — what are you asking the tester to do?
- [ ] Performance baseline recorded — run the same scenario without a tester to establish baseline metrics
- [ ] Crash recovery plan — if the game crashes, how do you resume? Is session data preserved?

## Input Recording

### What to Record

Every input event with enough context to replay it:

```
# Record format — one line per event
timestamp_ms | event_type | action_name | value | device

# Examples
0       | action_press   | throttle    | 1.0   | keyboard
16      | action_press   | steer_left  | 0.45  | gamepad_0
33      | action_release | steer_left  | 0.0   | gamepad_0
45      | mouse_motion   |             | (320,240) | mouse
```

### Recording Architecture

```
# Pseudocode
class InputRecorder:
    var _events: Array = []
    var _start_time: int = 0
    var _recording: bool = false

    func start_recording() -> void:
        _events.clear()
        _start_time = get_ticks_msec()
        _recording = true

    func stop_recording() -> void:
        _recording = false
        save_to_file()

    func on_input(event) -> void:
        if not _recording:
            return
        var elapsed = get_ticks_msec() - _start_time
        _events.append({
            "time": elapsed,
            "event": serialize_input_event(event)
        })
```

### Privacy Considerations

- Only record game inputs, not system-level keyboard events
- Don't record text input fields (passwords, usernames)
- Anonymize tester identity unless explicit consent is given
- Store session data locally — don't transmit without consent

## Metrics to Track During Play Sessions

### Performance Metrics (Continuous)

Sample these at regular intervals (every 100ms or every 6 frames):

| Metric | Why | Warning Sign |
|--------|-----|-------------|
| FPS | Smoothness | Drops below target (e.g., < 55 for 60Hz target) |
| Frame time (ms) | Stutter detection | Spikes > 2x average |
| Physics tick rate | Simulation stability | Deviation from target |
| Memory usage | Leak detection | Monotonic increase over time |
| Draw calls | Rendering load | Sudden jumps when entering areas |
| Audio buffer underruns | Audio quality | Any occurrence = audible glitch |

### Gameplay Metrics (Event-Driven)

Log these when they happen:

| Event | Data | Reveals |
|-------|------|---------|
| **Death/failure** | Position, time, cause | Difficulty spikes, unfair situations |
| **Menu open** | Which menu, from where | Where players seek help or options |
| **Setting changed** | Which setting, old/new value | What defaults are wrong |
| **Retry** | What was retried, attempt count | Frustration points |
| **Pause** | Duration, context | Where players take breaks (fatigue, confusion, or real break) |
| **Completion** | Time to complete, score, path taken | Intended vs actual player paths |
| **Backtrack** | Where, how far | Where players get lost |
| **Idle** | Duration, location | Confusion or distraction |

### Heatmap Data

For spatial analysis, record position samples at regular intervals:

```
# Pseudocode — sample every 500ms
func on_sample_timer() -> void:
    record_position_sample({
        "time": elapsed_time(),
        "position": player.global_position,
        "velocity": player.velocity.length(),
        "looking_at": camera.forward_direction()
    })
```

This data can generate:
- **Position heatmaps** — where do players spend time?
- **Death maps** — where do players fail?
- **Speed maps** — where do players slow down (confusion) or speed up (flow)?
- **Gaze maps** — what are players looking at?

## Crash and Error Reporting

### Error Capture Layers

| Layer | What It Catches | Implementation |
|-------|----------------|----------------|
| **Script errors** | Null references, type errors, assertion failures | Override error handler or hook into engine error signal |
| **Engine warnings** | Deprecated API usage, performance warnings | Log capture from engine output |
| **Crashes** | Segfaults, out-of-memory, infinite loops | Crash dump + pre-crash state snapshot |
| **Soft errors** | Game logic errors that don't crash (wrong state, missing data) | Application-level error logging |

### Pre-Crash State Snapshot

When an error occurs, immediately capture:

```
# Pseudocode
func on_error(error_info: Dictionary) -> void:
    var snapshot = {
        "error": error_info,
        "timestamp": get_datetime_string(),
        "scene": current_scene_path(),
        "player_state": serialize_player_state(),
        "recent_events": get_last_n_events(20),
        "recent_inputs": get_last_n_inputs(60),  # ~1 second
        "performance": get_recent_perf_samples(10),
        "call_stack": get_stack_trace()
    }
    save_crash_report(snapshot)
```

### Crash Recovery

After a crash:

1. On next launch, detect the crash report file
2. Offer to send the report (with user consent)
3. Restore game state from the last good checkpoint, not the crash point
4. Log that recovery occurred

## Performance Monitoring

### Frame Time Budget

Define your frame time budget and track where time is spent:

```
# For 60 FPS target: 16.67ms per frame
# Budget allocation (example):
#   Physics:    4ms
#   AI:         2ms
#   Rendering:  8ms
#   Audio:      1ms
#   Scripts:    1.5ms
#   Overhead:   0.17ms
```

### Spike Detection

Flag frames that exceed the budget:

```
# Pseudocode
const SPIKE_THRESHOLD_MS = 25.0  # 1.5x budget for 60fps

func on_frame_update(delta: float) -> void:
    var frame_ms = delta * 1000.0
    if frame_ms > SPIKE_THRESHOLD_MS:
        log_spike({
            "time": elapsed_time(),
            "frame_ms": frame_ms,
            "scene": current_scene_path(),
            "player_position": player.global_position,
            "active_objects": get_object_count()
        })
```

### Memory Monitoring

Track memory over time to detect leaks:

```
# Pseudocode — sample every 5 seconds
func on_memory_sample_timer() -> void:
    var sample = {
        "time": elapsed_time(),
        "static_mb": get_static_memory_bytes() / 1048576.0,
        "dynamic_mb": get_dynamic_memory_bytes() / 1048576.0,
        "object_count": get_engine_object_count()
    }
    memory_samples.append(sample)

    # Detect leak: memory growing consistently over 60 samples (5 minutes)
    if memory_samples.size() >= 60:
        var start = memory_samples[-60].dynamic_mb
        var end = memory_samples[-1].dynamic_mb
        if end > start * 1.2:  # 20% growth in 5 minutes
            Debug.warn("perf", "Possible memory leak: %.1f MB → %.1f MB over 5 min" % [start, end])
```

## Session Replay

### From Recorded Data

If you recorded inputs with timestamps, you can replay the session:

```
# Pseudocode
class SessionReplayer:
    var _events: Array
    var _event_index: int = 0
    var _replay_start_time: int

    func start_replay(session_file: String) -> void:
        _events = load_session_events(session_file)
        _event_index = 0
        _replay_start_time = get_ticks_msec()

    func on_frame_update(delta: float) -> void:
        var elapsed = get_ticks_msec() - _replay_start_time
        while _event_index < _events.size():
            var event = _events[_event_index]
            if event.time > elapsed:
                break  # Not time for this event yet
            inject_input(event)
            _event_index += 1
```

### Replay Limitations

Input replay is **not deterministic** unless:
- Physics is deterministic (same timestep, same floating-point behavior)
- Random seeds are recorded and replayed
- External inputs (network, time-of-day) are mocked

For non-deterministic engines, use **state replay** instead: record the full game state at regular intervals and interpolate between snapshots. This is more reliable but uses more storage.

### Replay with Annotations

Overlay session data on the replay:

- Performance graph synced to replay timeline
- Event markers (death, menu open, setting change) as visual pins on a timeline
- Heatmap overlay showing where the player spent time up to the current replay point

## Analyzing Test Results

### Common Friction Points

After collecting session data from multiple testers, look for these patterns:

| Pattern | Signal | Action |
|---------|--------|--------|
| **Repeated failure at same spot** | Multiple testers die/fail at same location | Difficulty tuning, better signposting |
| **Long time in menus** | Testers spend > 30s in settings or help | Defaults are wrong or UI is confusing |
| **Backtracking** | Testers go backwards from intended path | Navigation cues are insufficient |
| **Setting changes** | Multiple testers change the same setting | Default value is wrong |
| **Idle periods** | Testers stop moving for > 10s | Confusion about what to do next |
| **Rapid input** | Button mashing | Feedback is missing — player isn't sure their input registered |
| **Consistent performance drops** | FPS drops in same area across testers | Optimization target identified |

### Quantitative Analysis

For each session, compute:

```
# Pseudocode summary
session_summary = {
    "total_time": session_duration,
    "completion": percentage_of_objectives_completed,
    "deaths": count_of_deaths,
    "retries": count_of_retries,
    "avg_fps": mean(fps_samples),
    "min_fps": min(fps_samples),
    "fps_drops": count(fps < target),
    "errors": count_of_errors,
    "crashes": count_of_crashes,
    "settings_changed": list_of_changed_settings,
    "time_in_menus": total_menu_time,
    "time_playing": total_gameplay_time
}
```

### Cross-Session Comparison

Compare metrics across testers to find systemic vs individual issues:

- **Systemic:** All testers hit the same friction point (design problem)
- **Individual:** One tester struggles where others don't (skill gap or hardware difference)
- **Hardware-correlated:** Performance issues only on certain hardware (optimization target)

### Prioritizing Fixes

Rank issues by impact and frequency:

| Priority | Criteria | Example |
|----------|----------|---------|
| **P0** | Crash or data loss | Game crashes when loading track X |
| **P1** | Blocks progress for most testers | Testers can't figure out how to start a race |
| **P2** | Frequent frustration | 80% of testers die at the same corner |
| **P3** | Quality of life | Settings menu layout is confusing |
| **P4** | Polish | Minor FPS dip in one area |

## Implementation Checklist

When setting up user test monitoring for a project:

- [ ] Input recorder implemented and tested
- [ ] Game event logger with meaningful events defined
- [ ] Performance sampler (FPS, frame time, memory) at regular intervals
- [ ] Error/crash capture with pre-crash state snapshot
- [ ] Session metadata recorded (build version, hardware, tester)
- [ ] Data saved to organized session directories
- [ ] Replay system (input-based or state-based) functional
- [ ] Analysis scripts or tools for post-session review
- [ ] Privacy controls (what is recorded, consent, anonymization)
- [ ] Pre-session checklist documented for test facilitators
- [ ] Known good baseline recorded for performance comparison
