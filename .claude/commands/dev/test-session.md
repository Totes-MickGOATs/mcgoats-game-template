---
description: Run an interactive play-testing session with live monitoring and diagnostics
---

Run an interactive play-testing session. You are the test orchestrator -- launching the game, monitoring logs, and guiding the user through scenarios.

## Related Commands

During a test session, use these companion commands as needed:
- `/dev:check-performance` -- performance profiling analysis
- `/dev:e2e-test` -- automated E2E test runs (for scripted scenarios)

## Setup

1. **Determine test target**: Figure out what the user wants to test from conversation context. If unclear, ask: "What would you like to test? (e.g., a specific level, feature, or general gameplay)" and wait for a response.

2. **Determine configuration**: Identify any specific configuration needed (level, mode, debug flags). Use defaults if unspecified.

3. **Launch the game** with the appropriate configuration:
   ```
   # ENGINE-SPECIFIC: Replace with your engine's run command
   # Example: godot res://scenes/boot.tscn -- --test-track=test_track
   # Example: unity -executeMethod GameLauncher.TestMode -level TestLevel
   <engine_run_command> <test_configuration_args>
   ```

4. **Announce**: Tell the user the session is starting, what configuration is loaded, and what they should do first (e.g., "select a car and start driving"). Explain you'll be monitoring debug output and can capture diagnostics.

## Monitoring Loop

Once the game is running, enter a monitoring loop:

1. **Poll debug output** every few seconds using engine-specific log reading.
2. **Analyze each batch** of logs for:
   - Errors (exceptions, crashes, assertion failures)
   - Warnings (deprecation notices, resource issues)
   - Performance issues (long frame times, physics stutters, GC spikes)
   - Physics anomalies (NaN values, extreme velocities, objects falling through geometry)
   - Scene transition failures
   - Audio glitches (buffer underruns, missing sounds)
   - Any unexpected patterns
3. **Track findings** in a running list with timestamps and severity.
4. **Request user actions** when you need to test specific scenarios. Be specific: "Drive at full speed into the barrier on the left side of the track" not "test collisions". Explain WHY you're asking.
5. **Suggest adding debug logging** if you identify blind spots -- areas of code that produce no output and could be failing silently. Ask the user before making changes (requires restarting the session).
6. **Build a mental model** of what's working and what's not. Look for patterns across multiple log batches.

## Performance Diagnostics

Use these proactively during the session -- don't wait for problems:

- **Frame rate**: Monitor FPS, note any drops below target
- **Draw calls**: Check for excessive batches, overdraw
- **Memory**: Watch for leaks (steadily increasing allocation)
- **Physics time**: Ensure physics step stays within budget
- **Loading times**: Time scene transitions and asset loads
- **GC pressure**: Watch for allocation spikes in hot paths

## Session End

The session ends when:
- The user says "done", "stop", "end session", or similar
- The game process stops/crashes
- You've gathered enough data to provide actionable feedback

When ending:

1. **Capture final diagnostics** (if the game is still running)
2. **Stop the game process** (if still running)
3. **Produce a test report**:

### Test Session Report

**Session Summary**
- Configuration: [level/mode/settings]
- Duration: [approximate]
- Focus area: [what was being tested]

**Errors Found** (Critical)
- List each error with context and suggested fix

**Warnings** (Non-critical)
- List warnings that may indicate issues

**Performance Observations**
- Frame rate stability, physics performance, loading times
- Include specific metrics if captured

**Visual/Audio Issues**
- Any rendering, UI, or audio problems observed

**Suggested Improvements**
- Code changes to fix issues found
- Debug logging to add for future sessions
- Areas that need more testing

**Debug Blind Spots**
- Systems that produced no logs (may need instrumentation)
- Scenarios you couldn't test and why

## Important Notes

- Do NOT flood the user with raw log dumps. Summarize and highlight what matters.
- Be specific in action requests -- explain what to do and why.
- If you see the same error repeating, note it once with a count, don't report every occurrence.
- Track game state transitions to verify the flow worked correctly.
- Take diagnostics proactively, not just reactively.
- A session should feel collaborative -- you and the user are working together to find issues.
