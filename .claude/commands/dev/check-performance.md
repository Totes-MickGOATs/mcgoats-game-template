---
description: Audit the codebase for performance issues and report findings with suggested fixes
---

Audit the codebase for performance issues and report findings with file references and suggested fixes.

## Static Analysis (Code Patterns)

Search all game scripts for these common performance anti-patterns:

### Hot Path Allocations
1. **Node lookups in per-frame callbacks** -- `get_node()`, `find_child()`, `GetComponent<>()` in `_process()`, `_physics_process()`, `Update()`, `FixedUpdate()` (should be cached in initialization)
2. **Per-frame allocations** -- Array, Dictionary, List, or object creation inside hot loops or per-frame callbacks
3. **String operations in hot paths** -- concatenation, formatting, or comparison in per-frame code (should use interned strings, StringName, or cached values)

### I/O and Resource Loading
4. **Synchronous disk I/O in physics/render callbacks** -- file reads, resource loads in per-frame code
5. **Uncached resource lookups** -- loading the same resource repeatedly instead of caching on init
6. **Large textures loaded synchronously** -- should use background loading or streaming

### Signal and Event Patterns
7. **Signal connections created every frame** instead of once during initialization
8. **Event listeners added in loops** without corresponding removal (memory leak + performance)

### Algorithm Complexity
9. **Large match/if-elif chains** that could use dictionary/hashmap lookups
10. **Nested loops over large collections** in per-frame code (O(n^2) when O(n) or O(1) is possible)
11. **Unnecessary lerp/interpolation calls** with delta=0 or weight=1 (no-op but still computed)
12. **Redundant calculations** -- same value computed multiple times per frame across methods

### Memory and GC
13. **Closure/lambda creation in hot paths** -- captures variables and creates GC pressure
14. **Temporary object pools not used** for frequently allocated/deallocated objects (particles, projectiles)
15. **Large data structures rebuilt every frame** instead of incrementally updated

### Rendering
16. **Shader uniform updates every frame** when values haven't changed
17. **Unnecessary draw calls** -- objects that could be batched, instanced, or culled
18. **Overdraw** -- transparent materials stacked without consideration of fill rate

## Runtime Profiling (If Game Is Running)

If the game can be profiled live:

1. **Capture frame timing** -- identify the heaviest frames and what's running in them
2. **Monitor memory** -- look for steady growth (leaks) or periodic spikes (GC)
3. **Check draw calls** -- compare against budget for the target platform
4. **Physics time** -- ensure physics step stays within budget
5. **Audio** -- check for synthesis running when muted, buffer underruns

## Baseline Comparison

If performance baselines exist (e.g., `benchmarks/`, `baselines/`, or CI-tracked metrics):
1. Compare current measurements against baselines
2. Flag any regressions above threshold
3. Note any improvements

If no baselines exist, recommend establishing them for critical paths.

## Report Format

For each finding, report:

```
## [SEVERITY] Finding Title

**File:** path/to/file.ext, line N
**Pattern:** <which anti-pattern from the list above>
**Impact:** <estimated severity: high/medium/low>
**Current code:**
<snippet showing the problem>
**Suggested fix:**
<snippet showing the solution>
```

Group findings by severity (High -> Medium -> Low) and include a summary count at the top:

```
Performance Audit Results
=========================
High:   N findings
Medium: N findings
Low:    N findings

Estimated impact: <brief summary of the biggest wins>
```

## Rules

- Focus on actual hot paths -- code that runs per-frame or per-physics-tick. Don't flag one-time initialization code.
- Distinguish between measured problems and theoretical concerns. Measured > theoretical.
- Suggest fixes, not just problems. Every finding should have an actionable recommendation.
- Prioritize by impact -- a per-frame allocation in the main loop matters more than a one-time allocation in a menu.
- Check the project's target platform constraints (mobile has stricter budgets than desktop).
- If profiling tools are available, prefer measured data over static analysis.
