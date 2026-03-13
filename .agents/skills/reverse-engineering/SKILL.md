# Reverse Engineering & Debug Methodology Skill

Systematic approach to diagnosing bugs and understanding unfamiliar code. Use this when something is broken and you don't know why, or when you need to understand how an existing system works before modifying it.

## Core Principle: Chain of Custody

Every bug has a chain of custody — a sequence of events from the trigger to the symptom. Your job is to trace that chain backwards from what you can see (the symptom) to what actually went wrong (the root cause).

```
Symptom → Proximate Cause → Intermediate Steps → Root Cause
```

**Never fix the symptom.** Always trace to the root cause. A symptom fix creates a new bug waiting to happen.

## The Debugging Protocol

### Phase 1: Observe the Symptom

Before forming any hypothesis, collect raw facts:

1. **What exactly happens?** — Not "it's broken" but "the player falls through the floor at position (12, 0, -5) when landing from a jump"
2. **When does it happen?** — Always? Sometimes? Only after a specific sequence of actions?
3. **What changed recently?** — `git log --oneline -20` to see recent commits. `git diff HEAD~5` for recent changes.
4. **What are the exact error messages?** — Copy them verbatim. Don't paraphrase.
5. **Is it reproducible?** — If yes, write down the exact reproduction steps.

### Phase 2: Form a Hypothesis

Based on the symptoms, propose a specific, testable explanation:

- **Good hypothesis:** "The collision shape is not updating its transform after the animation plays, so the physics body uses stale collision geometry"
- **Bad hypothesis:** "Something is wrong with the physics"

A hypothesis must be:
- **Specific** — points to a particular mechanism or code path
- **Testable** — you can design an experiment to confirm or refute it
- **Falsifiable** — there exists evidence that would prove it wrong

### Phase 3: Gather Evidence

Test your hypothesis with the **minimum intervention** that produces useful data:

```
Read code → Add targeted logging → Inspect runtime state → Check config
```

**Do NOT** start changing code to "try things." That introduces new variables and makes the problem harder to diagnose.

#### Evidence-Gathering Techniques

| Technique | When to Use | Example |
|-----------|-------------|---------|
| **Read the code** | Always start here | Trace the call chain from symptom to origin |
| **Add logging** | When you need runtime values | `Debug.log("physics", "velocity: %s" % velocity)` |
| **Inspect state** | When values look wrong | Check variable values at breakpoints or via debug overlay |
| **Check config** | When behavior differs from expectation | Verify project settings, export values, config files |
| **Binary search** | When the failure is in a large change set | Bisect commits or comment out code blocks |
| **Minimal reproduction** | When the bug is intermittent | Strip the scenario to the simplest case that still fails |

### Phase 4: Confirm or Refute

Your evidence either supports or contradicts your hypothesis:

- **Supported:** Proceed to Phase 5 (fix). But verify with a second independent piece of evidence if possible — one data point can be coincidence.
- **Contradicted:** Go back to Phase 2 with a new hypothesis. The failed hypothesis is still valuable — it rules out a possibility.

### Phase 5: Fix and Verify

1. Write a failing test that captures the bug (TDD red phase)
2. Implement the minimum fix
3. Run the test — confirm it passes (TDD green phase)
4. Run related tests — confirm no regressions
5. Commit with a message that explains the root cause, not just the symptom

## Binary Search Technique

When you can't tell which of many changes (or code paths) introduced the bug:

### Git Bisect (for regression bugs)

```bash
git bisect start
git bisect bad                    # Current commit is broken
git bisect good <known-good-sha> # This commit was working
# Git checks out a midpoint — test it
git bisect bad   # or git bisect good
# Repeat until git identifies the culprit commit
git bisect reset
```

### Code Block Bisect (for logic bugs)

When the bug is in a single file or function:

1. Comment out the bottom half of the suspect code
2. Test — does the bug still occur?
3. If yes: bug is in the top half. Comment out the bottom half of the top half.
4. If no: bug is in the bottom half. Restore and comment out the top half of the bottom half.
5. Repeat until you've narrowed to a few lines.

**Important:** Undo all your bisect changes before implementing the fix. Bisecting is diagnostic, not therapeutic.

## Signal Tracing in Event-Driven Architectures

Event-driven systems (signals, events, callbacks) make bugs harder to trace because the call stack doesn't show the full story. The connection between emitter and receiver is configured at runtime, not visible in static code.

### Tracing Strategy

1. **Start from the symptom** — which handler is misbehaving?
2. **Find the signal connection** — search for `.connect(` with the handler name, or the signal name
3. **Find the emission point** — search for `.emit(` or `emit_signal(` with the signal name
4. **Trace the emission context** — what state is the emitter in when it fires?
5. **Check connection timing** — is the signal connected before or after the first emission?

### Common Signal Bugs

| Bug | Symptom | Root Cause |
|-----|---------|------------|
| **Late connection** | Handler never fires | Signal emitted before `connect()` runs |
| **Double connection** | Handler fires twice | `connect()` called twice without `is_connected()` guard |
| **Wrong signal** | Handler fires at wrong time | Connected to similar-named signal (e.g., `changed` vs `value_changed`) |
| **Stale reference** | Crash on signal emit | Connected object was freed but signal wasn't disconnected |
| **Argument mismatch** | Wrong data in handler | Signal emits different args than handler expects |

### Mapping Signal Flow

For complex systems, draw the signal flow:

```
ObjectA.signal_x → ObjectB.handler_y → ObjectB.signal_z → ObjectC.handler_w
```

This makes it visible where the chain breaks. Check each arrow independently.

## State Inspection Patterns

### Runtime Variables

When you suspect a variable has the wrong value:

1. **Add a log at the assignment point** — not just the usage point. You need to know when and why it changed.
2. **Check initialization** — is the variable set to a sane default? Is it set before first use?
3. **Check all writers** — search for every place that assigns to this variable. One of them is wrong.
4. **Check timing** — is the variable read before it's written? Race conditions between initialization order.

### Config Files

When behavior doesn't match what the code says:

1. **Verify the config is loaded** — add logging to the config-loading code
2. **Check for overrides** — project settings, user settings, command-line args, environment variables
3. **Check file paths** — is the code loading the config you think it's loading?
4. **Check parse errors** — a malformed config may silently use defaults

### Logs

When reading existing logs:

1. **Find the last normal log entry** — the bug happened between this and the first abnormal entry
2. **Check timestamps** — gaps in logging may indicate a hang or crash
3. **Filter by subsystem** — use tags/categories to isolate relevant entries
4. **Look for warnings before errors** — warnings often foreshadow the real problem

## When to Add Logging vs Read Existing Logs

| Situation | Action |
|-----------|--------|
| You don't understand the code flow | Read existing logs first, then add logging at decision points |
| You understand the flow but not the values | Add targeted logging at the suspect code path |
| The bug is intermittent | Add persistent logging (not just for this debug session) with a tag you can filter |
| The bug happens in production/CI only | Add logging that will survive to the next CI run — don't remove it after |
| You're about to add more than 10 log lines | Stop. You're fishing. Form a hypothesis first. |

### Structured Logging

Always use structured, tagged logging:

```
# Good — filterable, searchable, informative
Debug.log("physics", "wheel %d slip: lateral=%.2f longitudinal=%.2f" % [i, lat, lon])

# Bad — noise in the log, no context, can't filter
print("slip is " + str(slip))
```

## Common Pitfalls

### Correlation vs Causation

"The bug started happening after I changed X" does not mean X caused the bug. It might be:
- A pre-existing bug that X's change made visible
- A timing change that surfaced a race condition
- An unrelated change that was merged around the same time

**Test:** Revert X. Does the bug go away? If yes, X is involved (but may not be the root cause). If no, X is a red herring.

### Confirmation Bias

Once you have a hypothesis, you'll unconsciously filter evidence to support it. Counter this by:
- **Actively trying to disprove your hypothesis** — what evidence would contradict it?
- **Asking "what else could cause this?"** before committing to a fix
- **Having a second pair of eyes** review your diagnosis

### Fixing Symptoms, Not Causes

| Symptom Fix (Wrong) | Root Cause Fix (Right) |
|---------------------|----------------------|
| Add a null check before the crash | Fix why the variable is null |
| Clamp the value to a safe range | Fix why the value goes out of range |
| Add a retry loop | Fix why the operation fails |
| Catch and ignore the exception | Fix the condition that throws |

Symptom fixes are sometimes necessary as **temporary stopgaps** (to unblock a release), but they must always be followed by a root cause fix. Leave a `# TODO: root cause fix needed` comment with a description.

### Premature Code Changes

The most common debugging anti-pattern:

1. See a bug
2. Immediately start changing code to "fix" it
3. The change doesn't work, or introduces a new bug
4. Now you're debugging two problems

**Rule:** Do not change production code until you can explain the root cause in one sentence. If you can't articulate it, you haven't found it yet.

## Post-Mortem Process

After fixing a significant bug, document:

1. **Symptom** — what was observed
2. **Root cause** — what actually went wrong and why
3. **Fix** — what was changed and why that addresses the root cause
4. **Prevention** — what can be done to prevent similar bugs (test, lint rule, design change, documentation)
5. **Detection** — how could this bug have been caught earlier? (better tests, better logging, code review focus area)

Update project memory or documentation with any new gotchas, patterns, or rules discovered during the investigation. The next agent or developer shouldn't have to rediscover this knowledge.

## Checklist: Before You Say "Fixed"

- [ ] I can explain the root cause in one sentence
- [ ] I have a test that fails without the fix and passes with it
- [ ] I verified the fix doesn't break related tests
- [ ] I checked for similar patterns elsewhere in the codebase that might have the same bug
- [ ] I updated documentation/memory with the finding
- [ ] The commit message explains the root cause, not just "fix bug"
