---
name: game-optimization-performance
description: "Project-specific optimization and performance skill. Covers audio smoothing patterns, frame budget testing, Performance singleton benchmarks, Server API usage, profiling workflow, and known performance pitfalls. Use when diagnosing glitches, optimizing frame times, writing performance tests, or fixing audio/visual artifacts."
---

# Game Optimization & Performance

Project-specific optimization patterns, benchmarking, and known pitfalls.

## Architecture

| Component | Location | Role |
|-----------|----------|------|
| AudioManager | `scripts/autoloads/audio_manager.gd` | Bus hierarchy, sidechain compressor, volume API |
| CarAudio | `scripts/audio/car_audio.gd` | Engine/wind/servo/landing audio (sample-based) |
| TireAudio | `scripts/audio/tire_audio.gd` | Per-wheel tire squeak with envelope smoothing |
| ImpactAudio | `scripts/audio/impact_audio.gd` | Collision/scrape audio (sample-based, pooled) |
| GraphicsManager | `scripts/autoloads/graphics_manager.gd` | Tier switching, DOF, config persistence |
| Debug overlays | `scripts/debug/` | F3-F8 visual profiling overlays |
| EffectLOD | Various effect scripts | WorldScale-aware distance culling |

## Optimization Principles

### The Hierarchy (Most to Least Impact)

1. **Design-level** -- Choose the right algorithm/architecture (physics engine, sample-based audio vs synthesis)
2. **Algorithm-level** -- Fix math that produces bad output (audio envelope smoothing, parameter clamping)
3. **Data-level** -- Cache locality, compact storage, precalculation
4. **Low-level/Server API** -- Direct RenderingServer/PhysicsServer/AudioServer calls (only when node overhead is the bottleneck)

### When to Use Server APIs

Server APIs (`RenderingServer`, `PhysicsServer3D`, `AudioServer`) bypass the scene tree for maximum performance. Use them ONLY when dealing with thousands of instances where node overhead is measurable.

| System | Current Approach | Server API Needed? |
|--------|-----------------|-------------------|
| Vehicles (8-12 max) | Full Vehicle nodes | No -- node count is fine |
| Tire marks/decals | Node-based decals | Maybe at 500+ marks |
| Dust/particles | GPUParticles3D | No -- already GPU-side |
| Spectator crowd (future) | N/A | Yes -- `RenderingServer.instance_create()` |
| Foliage instances | MultiMesh | Already optimal |

**Critical rule:** Never poll Server APIs per-frame. They run asynchronously; calling functions that return values stalls them. Write-only access (setting transforms, volumes) is fine.

```gdscript
# GOOD: Write-only, per-frame is fine
RenderingServer.instance_set_transform(instance, xform)

# BAD: Stalls the server, kills performance
var current_xform = RenderingServer.instance_get_transform(instance)  # DON'T
```

### Bottleneck Identification

1. **Profile first** -- Use Godot Profiler (Debug > Profiler), F3-F8 debug overlays, `Performance` singleton. **Known bug:** Time spent waiting for built-in servers (rendering, physics, audio) may not appear in profiler results -- if a function seems fast but frame time is high, suspect server-side stalls.
2. **Hypothesis test** -- Add/remove instances, measure impact
3. **Binary search** -- Comment out half the frame work, narrow down
4. **Check GPU vs CPU** -- If CPU optimization doesn't improve frame time, you're GPU-bound

```gdscript
# Quick bottleneck check
var cpu_time := Performance.get_monitor(Performance.TIME_PROCESS)
var physics_time := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
var fps := Performance.get_monitor(Performance.TIME_FPS)
```

### Manual Function Timing

When profiler identifies a bottleneck area, use manual timing to measure specific functions precisely:

```gdscript
# Time a specific function with microsecond precision
var time_start := Time.get_ticks_usec()
update_enemies()
var time_end := Time.get_ticks_usec()
print("update_enemies() took %d microseconds" % (time_end - time_start))
```

**Key rules for manual timing:**
- Run the function **1000+ times** and average -- single measurements are unreliable due to timer precision and CPU scheduling
- **CPU cache effects**: First run is always slower (cache miss). Second+ runs benefit from cached data. Always use averages.
- Re-time after every optimization attempt to verify it actually helped

### CPU Cache Awareness

- CPUs load data from small, fast cache -- not directly from system RAM
- **Cache miss** = data not in cache, CPU stalls waiting for main memory fetch
- Sequential/linear memory access patterns = cache-friendly = fast
- Random/scattered memory access = cache misses = slow
- Godot's Server APIs already optimize for cache locality (rendering, physics)
- Most relevant when writing GDExtensions or processing large custom data arrays

### Language Performance Tiers

| Language | Speed | Use Case |
|----------|-------|----------|
| **GDScript** | Slowest (ease-of-use optimized) | Gameplay logic, UI, orchestration -- fine for most game code |
| **C#** | Medium (watch for GC pauses) | Heavy calculations; use object pooling to avoid GC stalls |
| **C++ (GDExtension)** | Fastest | Hot inner loops, thousands of instances, custom physics |

**Rule:** If GDScript profiling shows a function is the bottleneck, consider moving just that function to C++ via GDExtension. Don't rewrite entire systems.

### Threading

- Use threads for parallelizable heavy work (pathfinding batches, procedural generation)
- **Danger:** Race conditions when multiple threads access shared data. Use mutexes or message queues.
- Godot's scene tree is NOT thread-safe -- never modify nodes from worker threads
- Debug threaded code is significantly harder; prefer single-threaded until profiling proves it's needed

### SceneTree Node Cost

- Every node has overhead: `_process()`, `_physics_process()`, `_notification()` propagation through the tree
- Thousands of nodes are fine; tens of thousands may bottleneck (platform-dependent -- profile on target hardware)
- **Fewer nodes with more content each** outperforms many tiny nodes
- **Detach instead of hide/pause:** `remove_child(node)` is cheaper than `visible = false` or `process_mode = DISABLED` -- the node exits the tree entirely. Re-attach with `add_child()` when needed. Keep a reference to avoid GC.
- For truly massive instance counts, bypass the SceneTree entirely with Server APIs

### Physics Optimization

- **Simplified collision shapes:** Use approximate geometry (convex hulls, boxes) instead of trimesh for moving objects
- **Remove off-screen physics objects:** Detach or disable physics bodies outside the active area
- **Physics tick rate:** Default 60Hz is correct for real-time vehicle games. Reducing to 30Hz saves CPU but adds input lag and jitter.
- **Fixed timestep interpolation:** Godot's built-in `physics/common/physics_interpolation` smooths rendered positions between physics ticks. Orders of magnitude cheaper than running more physics ticks. Eliminates jitter if tick rate is reduced.

## GPU Optimization

### Draw Calls & State Changes

- Every API command (Vulkan/OpenGL) has validation overhead
- **Goal:** Minimize draw calls and group similar objects to reduce state changes
- Godot automatically batches 2D items; 3D requires more manual attention

### Material & Shader Reuse

- **Reuse materials aggressively:** 20,000 objects with 100 shared materials >> 20,000 objects with 20,000 unique materials
- **Shader reuse is automatic** for StandardMaterial3D with same feature flags (even with different parameters)
- Use **texture atlases** to reduce texture switches when many unique materials are unavoidable
- For custom shaders: share the same Shader resource across materials, vary only uniforms

### Vertex vs Pixel Cost

- On desktop/console: **vertex cost is low** -- GPUs handle millions of triangles efficiently
- On mobile: tile-based rendering makes vertex processing more expensive; avoid geometry concentration in small screen areas
- **LOD is critical:** Use lower-detail meshes for distant objects. Avoid sub-pixel triangles even on desktop.
- Additional vertex cost from: skeletal animation (skinning), shape keys (morphs), vertex lighting

### Fill Rate & Fragment Shaders

- Fragment shading cost has grown massively with resolution (4K = 27x more pixels than 640x480)
- **Fill rate test:** Disable V-Sync, compare FPS at large vs tiny window. Big FPS increase = fill rate-limited.
- **Reduce fill rate cost:** Simplify shaders, reduce texture count/size, disable expensive StandardMaterial3D options
- **Variable rate shading:** On supported hardware, reduces fragment shading resolution in less-important screen areas without affecting edge sharpness. Good for reducing fill rate cost with minimal visual impact.
- For particles: force vertex shading in material to reduce fragment cost

### Texture Best Practices

- **VRAM compression:** Always enabled for 3D textures (reduces GPU memory bandwidth). Artifacts are invisible on 3D geometry.
- Disable VRAM compression only for pixel art textures
- Minimize texture reads per fragment shader -- each read is expensive (especially with trilinear/mipmap filtering)
- Most Android devices don't support VRAM compression for transparent textures

### Transparency & Blending

- **Depth prepass:** Enabled by default in Forward+ and Compatibility. Writes to Z-buffer first, then only runs fragment shaders on the "winning" (frontmost) pixel. This makes opaque rendering efficient -- but transparent objects can't benefit from it.
- **Transparent objects are expensive:** Cannot use Z-buffer optimization, must render back-to-front (sorted by material, not depth -- can cause visual artifacts with overlapping transparent objects), every fragment is shaded even if occluded
- Overlapping transparent objects multiply fill rate cost
- **Prefer opaque geometry** over transparency cheats when possible
- Keep transparent areas small to minimize fill rate impact
- **Separate transparent surfaces:** If a mesh has a small transparent section, split it into a separate surface with its own material. This lets the opaque parts benefit from depth prepass while limiting the transparent area.

### Shadows & Post-Processing

- Shadows are expensive for both writing and reading shadowmaps
- **Reduce shadowmap size** for distant/small lights
- **Disable shadows** on OmniLights/SpotLights that are small, distant, or visually unimportant
- Always profile post-processing effects on target hardware

### MultiMesh for Mass Instances

Use `MultiMesh` when rendering hundreds to millions of identical objects (foliage, debris, crowd):

```gdscript
# MultiMesh setup for thousands of instances (single draw call)
extends MultiMeshInstance3D

func _ready() -> void:
    multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.instance_count = 10000
    multimesh.visible_instance_count = 1000  # Only show what's needed

    for i in multimesh.visible_instance_count:
        multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(i * 20, 0, 0)))
```

**MultiMesh key rules:**
- **No per-instance culling** -- entire MultiMesh is drawn or not. Split into spatial chunks for large worlds. Set a **custom visibility AABB** (`MultiMesh.custom_aabb`) to control culling bounds when instances spread beyond the auto-calculated AABB.
- Control visible count dynamically with `visible_instance_count` (allocate max, show only what's needed)
- Per-instance logic possible via vertex shader (`INSTANCE_ID`, `INSTANCE_CUSTOM`) + data textures (use `Image.FORMAT_RGBAF` floating-point format for encoding per-instance data into textures the shader can sample)
- For C++ GDExtension: `RenderingServer.multimesh_set_buffer()` sets all transforms in one call (linear memory, cache-friendly, multi-threadable)

| Instance Count | Recommended Approach |
|---------------|---------------------|
| < 100 | Individual nodes |
| 100 - 1,000 | Nodes with LOD, or MultiMesh |
| 1,000 - 100,000 | MultiMesh |
| 100,000+ | MultiMesh + GDExtension for data |

### Multi-Platform Performance

- **Design for lowest common denominator**, add enhancements for powerful hardware
- Test on all target platforms early and often (especially mobile)
- Mobile tile-based renderers: post-processing, viewport textures, and cross-tile effects are expensive
- Consider Compatibility rendering method when targeting both desktop and mobile

### Pipeline Compilation & Shader Stutter

Pipeline compilation (GPU driver converting shader intermediate format to GPU-native code) causes "shader stutter" on first playthrough. Godot 4.4+ mitigates this:

**Ubershaders:** Godot uses specialization constants to optimize shader pipelines for specific rendering configurations. Ubershaders are a generic version that can change these constants at runtime, allowing Godot to precompile just one pipeline at load time and compile optimized specializations in the background during gameplay. This eliminates most first-encounter stutters.

**Pipeline precompilation:** Pipelines are precompiled when meshes load or nodes are added to scene. Works with background threading during loading screens.

**Shader baker (4.5+):** Bakes compiled shader code into PCK at export time, skipping the compilation step entirely. Enable in Export > Shader Baker > Enabled. Especially beneficial for D3D12/Metal (slower initial compilation than Vulkan). **Platform limitations:** The editor can only bake shaders for drivers supported on the current OS (Windows: Vulkan + D3D12, macOS: Vulkan + Metal, Linux/Android: Vulkan only). Only works for Forward+ and Mobile renderers (not Compatibility). Baked shaders match the `rendering/rendering_device/driver` project setting for the target platform.

**Avoiding pipeline stutters:**
- Load meshes/shaders during loading screens, not during gameplay
- Ensure rendering features are active in an early scene before loading main assets. **Full feature list that triggers pipeline compilation:** MSAA level, ReflectionProbes, separate specular (SSS), motion vectors (TAA/FSR2/motion blur), normal+roughness buffer (SDFGI/VoxelGI/SSR/SSAO/SSIL), LightmapGI, VoxelGI, SDFGI, multiview (XR), 16/32-bit shadow depth, omni shadow mode (dual paraboloid vs cubemap)
- For dynamically-spawned effects (explosions, dust, particles): attach a **hidden instance** of each effect type as a child of a persistent, always-present node (e.g., the player). Enable "Editable Children" on the instance and disable its script + hide visual nodes. The engine precompiles pipelines when the node enters the scene tree, even if invisible. This prevents first-use stutters during gameplay.
- **Never change MSAA level, GI settings, or shadow precision during gameplay** -- triggers immediate recompilation stutters. If these must be configurable, apply changes from an options screen behind a loading screen.
- Use Godot debugger's pipeline compilation monitors to identify stutter sources (Canvas/Mesh/Surface/Draw/Specialization)

**Monitor categories:**
| Monitor | Meaning | Stutter Risk |
|---------|---------|-------------|
| Canvas | 2D node drawn first time | Yes (no 2D precompilation yet) |
| Mesh | 3D mesh loaded, pipelines identified | Only if loaded during gameplay |
| Surface | Node added to scene tree first time | Only on first frame after add |
| Draw | Ubershader wasn't precompiled (bug) | Yes -- report to Godot devs |
| Specialization | Background optimization | No (async) |

### 3D Rendering Optimization

**Occlusion culling:** Enable OccluderInstance3D nodes to prevent rendering objects behind walls/buildings. May require level design changes (add walls to block long sightlines).

**Level of detail (LOD):**
- Automatic mesh LOD on import (Mesh LOD)
- Manual visibility ranges (HLOD) for node-level control
- Decals/lights have Distance Fade properties
- Use billboard impostors for distant objects (trees, foliage)
- Combine multiple distant objects into single impostor groups
- **Re-rendered imposters:** For distant scenery (track buildings, tree lines), periodically re-render the object group onto a texture from the current viewing angle rather than using a static billboard. Only needed when the viewer moves far enough for the angle to change significantly. Complex to implement but effective for detailed distant environments in racing tracks.

**Static mesh joining:** Combine static meshes that are near each other into a single mesh (done by artists in Blender or programmatically via addons). Reduces draw calls significantly for large groups of small objects. **Tradeoff:** joined meshes can't be individually culled -- an off-screen city joined to one on-screen blade of grass renders the entire city. Best for distant or clustered low-poly objects.

**Automatic instancing (Forward+ only):** MeshInstance3D nodes with same mesh + opaque/alpha-scissor material are automatically batched. No setup needed. Alpha-blended materials must use MultiMesh instead.

**Baked lighting:**
- Use LightmapGI for static scenes -- dramatically cheaper than realtime
- Set lights to `Static` bake mode for best performance
- Keep DirectionalLight3D as `Dynamic`, set omni/spot to `Static` for good balance
- Static lights can't cast shadows on lightmapped meshes

**Animation optimization:**
- Skeletal animation (skinning) is CPU-expensive -- lower polycount for animated models
- Reduce animation rate for distant/occluded meshes
- Use VisibleOnScreenEnabler3D to pause animations off-screen

**Large worlds:**
- Tile-based loading to limit memory and processing
- Enable large world coordinates for worlds >~5km from origin
- Or periodically re-center the world around the player to avoid floating point precision loss

### Threading in Godot

**Thread creation is slow** (especially on Windows). Create threads during loading, not just-in-time.

**Thread safety rules:**

| System | Thread-Safe? | Notes |
|--------|-------------|-------|
| Global scope singletons | Yes | Ideal for Server API access from threads |
| Scene tree | **No** | Use `call_deferred()` / `set_deferred()` for node operations |
| Building scene chunks | Partial | Create node trees off-tree in thread, `add_child.call_deferred()` on main thread |
| RenderingServer | Yes (with setting) | Enable Rendering > Driver > Thread Model = Separate. **Warning:** has known bugs, may not be stable in all scenarios. |
| PhysicsServer3D | Yes (with setting) | Enable Physics > 3D > Run on Separate Thread. **Note:** physics callbacks fire on the physics thread, not main thread -- code assuming main-thread execution will break. |
| NavigationServer3D | Yes | Queries run in true parallel |
| Resource loading | Partial | One thread loading is safe; multiple threads risk crashes. Use `ResourceLoader.load_threaded_request()` for safe background loading. |
| GDScript arrays/dicts | Partial | Read/write elements OK; resize/add/remove requires mutex |

**Mutex best practices:**
- Lock as briefly as possible -- long locks defeat threading benefits
- Avoid locking too frequently (lock/unlock is expensive)
- Never access GPU directly from threads (texture creation, image data retrieval)
- **Always call `Thread.wait_to_finish()`** in `_exit_tree()` -- mandatory for portability, even if the thread has already returned

```gdscript
# Thread + Mutex pattern
var _mutex := Mutex.new()
var _thread := Thread.new()
var _data := 0

func _ready() -> void:
    _thread.start(_worker)

func _worker() -> void:
    _mutex.lock()
    _data += 1
    _mutex.unlock()

func _exit_tree() -> void:
    _thread.wait_to_finish()
```

**Semaphore pattern** for on-demand thread work:
```gdscript
# Thread sleeps until semaphore.post() wakes it
var _semaphore := Semaphore.new()

func _thread_function() -> void:
    while true:
        _semaphore.wait()  # Suspends until post()
        # ... do work ...

func request_work() -> void:
    _semaphore.post()  # Wake the thread
```

### Vertex Animation via Shader (MultiMesh + Fish Pattern)

For animating thousands of identical objects (fish, birds, crowd), use vertex shaders instead of skeletal animation:

- Define motion as `cos(TIME + offset)` functions in vertex shader
- Pass per-instance phase/speed via `INSTANCE_CUSTOM` (set via `set_instance_custom_data()`)
- Four composable motions: side-to-side, pivot, wave (panning cos along spine), twist (panning roll)
- Use `smoothstep` mask to limit motion to specific body regions
- Entirely GPU-side -- zero CPU cost per instance

```glsl
// Per-instance animation offset via INSTANCE_CUSTOM
float time = (TIME * (0.5 + INSTANCE_CUSTOM.y) * time_scale) + (6.28318 * INSTANCE_CUSTOM.x);
float body = (VERTEX.z + 1.0) / 2.0;
float mask = smoothstep(mask_black, mask_white, 1.0 - body);
VERTEX.x += cos(time + body) * mask * wave;
```

## Audio Performance & Smoothing

### The Envelope Smoothing Pattern

Audio parameter changes (volume, pitch) MUST be smoothed to avoid audible discontinuities (pops, clicks, stuttering). TireAudio implements this correctly:

```gdscript
# CORRECT: Attack/release envelope (TireAudio pattern)
const VOLUME_ATTACK: float = 12.0   # per-second rise rate
const VOLUME_RELEASE: float = 6.0   # per-second fall rate (slower = no clicks)

var _smooth_volume: float = 0.0

func _update_volume(target: float, delta: float) -> void:
    if target > _smooth_volume:
        _smooth_volume = minf(_smooth_volume + VOLUME_ATTACK * delta, target)
    else:
        _smooth_volume = maxf(_smooth_volume - VOLUME_RELEASE * delta, target)
```

```gdscript
# WRONG: Direct assignment causes discontinuities
player.volume_db = linear_to_db(vol)  # jumps instantly, causes pops
player.pitch_scale = new_pitch         # pitch discontinuity = audible click
```

### Audio Constants Reference

| System | Constant | Value | Purpose |
|--------|----------|-------|---------|
| CarAudio | `SAMPLE_RPM` | 4000.0 | Engine pitch reference RPM |
| CarAudio | `ENGINE_FREE_SPIN` | 1.5 | Airborne motor multiplier |
| CarAudio | Engine RPM lerp | 8.0 | Per-second smoothing rate |
| TireAudio | `VOLUME_ATTACK` | 12.0/s | Fast slip onset |
| TireAudio | `VOLUME_RELEASE` | 6.0/s | Slow silence fade |
| TireAudio | `SLIP_THRESHOLD` | 0.15 | Below this: silent |
| TireAudio | `SILENCE_DB` | -80.0 dB | Silence floor |
| TireAudio | `MAX_VOLUME_DB` | -6.0 dB | Peak tire volume |
| AudioManager | Compressor threshold | -20.0 dB | Music ducking starts |
| AudioManager | Compressor ratio | 3.0 | 3:1 gentle compression |
| AudioManager | Compressor attack | 20000.0 us | 20ms impact response |
| AudioManager | Compressor release | 200.0 ms | Smooth musical return |

### Known Audio Pitfalls

1. **Compressor attack_us is microseconds** -- `20.0` = 0.02ms (< 1 audio sample at 44.1kHz). Must be `20000.0` for 20ms.
2. **Engine/wind/servo have no envelope smoothing** -- Direct `volume_db` assignment per frame causes pops. Apply attack/release pattern.
3. **Servo steer_speed spikes at low delta** -- `absf(steer - prev) / maxf(delta, 0.001)` amplifies at high framerates. Smooth the output.
4. **Landing min intensity = 0.2** -- Soft landings (<6 kmh) still play at -14dB. Lower floor or add speed gate.
5. **ImpactAudio methods never called** -- `play_collision()` and `play_scrape()` have no call sites. Need Vehicle collision wiring.
6. **AudioStreamGenerator requires explicit play()** -- `autoplay=true` unreliable on programmatic nodes. Only affects `ui_audio.gd` and `ambient_soundscape.gd`.

### Audio Bus Rules

- Never query AudioServer per-frame (stalls audio thread)
- Write-only access to bus volumes is fine
- All volume changes go through `AudioManager.set_bus_volume()`
- Bus hierarchy: Master -> Music / SFX -> Engine / Tires / Impact / Ambient / UI

## Benchmarking & Performance Testing

### GUT Frame Timing Tests

```gdscript
## Assert that N frames stay under budget (60fps = 16.67ms)
func test_frame_budget() -> void:
    var start := Time.get_ticks_usec()
    for i in 100:
        await get_tree().process_frame
    var elapsed := Time.get_ticks_usec() - start
    var avg_ms := elapsed / 100.0 / 1000.0
    assert_lt(avg_ms, 16.67, "Average frame should be under 16.67ms (60fps)")
```

### Performance Monitor Snapshots

```gdscript
## Capture performance baseline for regression detection
func capture_perf_snapshot() -> Dictionary:
    return {
        "fps": Performance.get_monitor(Performance.TIME_FPS),
        "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
        "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
        "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
        "memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
    }
```

### Audio Parameter Sweep Tests

Test that audio calculations produce sane values at edge cases:

```gdscript
## Parameterized test: engine pitch stays in valid range at all RPMs
func test_engine_pitch_range(rpm: float, min_pitch: float, max_pitch: float,
        test_parameters := [
            [0.0, 0.01, 0.5],       # idle
            [1200.0, 0.2, 0.4],      # low RPM
            [4000.0, 0.9, 1.1],      # sample RPM (should be ~1.0)
            [8000.0, 1.8, 2.2],      # high RPM
            [12000.0, 2.5, 4.0],     # free-spin overshoot
        ]) -> void:
    var pitch := maxf(rpm / CarAudio.SAMPLE_RPM, 0.01)
    assert_between(pitch, min_pitch, max_pitch,
        "Engine pitch at %d RPM should be in [%.2f, %.2f]" % [rpm, min_pitch, max_pitch])
```

### Audio Discontinuity Detection

Test that consecutive frames don't produce parameter jumps exceeding a threshold:

```gdscript
## Assert that audio parameter doesn't jump more than max_delta per frame
func assert_smooth_transition(values: Array[float], max_delta: float, label: String) -> void:
    for i in range(1, values.size()):
        var delta := absf(values[i] - values[i - 1])
        assert_lt(delta, max_delta,
            "%s jumped %.3f between frames %d-%d (max: %.3f)" % [label, delta, i - 1, i, max_delta])
```

### Memory Leak Detection

```gdscript
## Check that a scene doesn't leak resources after cleanup
func test_no_memory_leak() -> void:
    var mem_before := Performance.get_monitor(Performance.MEMORY_STATIC)
    # ... run test scenario ...
    # Force cleanup
    await get_tree().process_frame
    var mem_after := Performance.get_monitor(Performance.MEMORY_STATIC)
    var leaked_kb := (mem_after - mem_before) / 1024.0
    assert_lt(leaked_kb, 100.0, "Scene leaked %.1f KB" % leaked_kb)
```

### Draw Call Budget

```gdscript
## Assert draw calls stay within budget for a standard scene
func test_draw_call_budget() -> void:
    # Load a representative scene
    var runner := scene_runner("res://scenes/main.tscn")
    await get_tree().process_frame
    await get_tree().process_frame  # let scene stabilize
    var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    assert_lt(draws, 500, "Draw calls should be under 500 for standard track")
```

### Custom Benchmark Script Pattern

```gdscript
## Standalone benchmark: spawn N vehicles, measure frame times over M seconds
extends Node

var _frame_times: Array[float] = []

func _ready() -> void:
    # Spawn vehicles, set up scene...
    pass

func _process(delta: float) -> void:
    _frame_times.append(delta * 1000.0)
    if _frame_times.size() >= 600:  # 10 seconds at 60fps
        _report_and_quit()

func _report_and_quit() -> void:
    _frame_times.sort()
    var avg := _frame_times.reduce(func(a, b): return a + b) / _frame_times.size()
    var p99 := _frame_times[int(_frame_times.size() * 0.99)]
    var worst := _frame_times[-1]
    print("Benchmark: avg=%.2fms p99=%.2fms worst=%.2fms" % [avg, p99, worst])
    get_tree().quit()
```

## GDScript Performance Patterns

### Cache Node References

```gdscript
# GOOD: Cached at init
@onready var _player := $Player

# BAD: Tree traversal every frame
func _process(_delta):
    var player = get_node("Player")  # 60x/sec tree walk
```

### Move Calculations Outside Loops

```gdscript
# GOOD: Precalculate
var inv_count := 1.0 / items.size()
for item in items:
    item.weight = item.mass * inv_count

# BAD: Division every iteration
for item in items:
    item.weight = item.mass / items.size()
```

### Use Typed Arrays

```gdscript
# GOOD: Typed = faster iteration, less memory
var positions: Array[Vector3] = []

# BAD: Variant array
var positions = []
```

### Avoid Allocations in Hot Paths

```gdscript
# GOOD: Reuse pre-allocated object
var _temp_transform := Transform3D()
func _physics_process(_delta):
    _temp_transform.origin = new_position
    RenderingServer.instance_set_transform(rid, _temp_transform)

# BAD: New allocation every frame
func _physics_process(_delta):
    var xform := Transform3D(Basis(), new_position)  # allocates
```

## Project-Specific Optimization Notes

### Vehicle Count Scaling

- 8-12 vehicles is the target. Each Vehicle has ~20 child nodes (wheels, effects, audio)
- Total node budget per vehicle: ~200 nodes including effects
- At 12 vehicles: ~2400 nodes. Well within Godot's comfort zone.
- If more vehicles needed: disable non-visible effects via EffectLOD

### Effect LOD System

Effects use WorldScale-aware distance culling:
- Close: Full detail (particles, tire marks, dust)
- Medium: Reduced particles, no tire marks
- Far: Minimal (no particles, simplified audio)

### Terrain3D Performance

- Terrain3D handles its own LOD internally
- Don't fight it -- let the addon manage mesh detail
- Texture count is the main GPU cost: keep terrain material slots reasonable

### Physics (Jolt)

- Jolt is already highly optimized
- Main cost: collision detection between vehicles
- Layer masks keep costs low: vehicles only collide with terrain (1) and vehicles (2)
- Don't enable `contact_monitor` on vehicles unless needed (adds overhead)

## Profiling Workflow

1. **F8** -- Toggle verbose debug logging (Debug autoload)
2. **F3/F5/F6/F7** -- Visual physics overlays (suspension, traction, chassis, air)
3. **Debug > Profiler** -- Godot's built-in profiler
4. **Performance singleton** -- Programmatic monitoring in tests
5. **External GPU profilers** -- NVIDIA Nsight, RenderDoc for draw call analysis
6. **External CPU profilers** -- Callgrind (Valgrind) for C++ engine/driver profiling. Relevant for profiling GDExtensions. Compile with debug symbols, run via `valgrind --tool=callgrind ./godot`, view results in KCachegrind. Shows Inclusive (function + children) vs Self (function only) time, call counts per function. Can reveal time spent in graphics driver vs engine code (e.g., identifying that 50% of CPU time is in `libglapi`/`i965_dri` = driver bottleneck, not engine code)

### What to Profile First

| Symptom | Likely Cause | Tool |
|---------|-------------|------|
| Low FPS (constant) | GPU-bound: too many draw calls, overdraw | Godot Profiler + GPU profiler |
| Spikes/stutter | GC, allocations in hot path, physics spikes | Profiler + `Performance.TIME_PROCESS` |
| Audio pops/clicks | Unsmoothed parameter changes | Audio parameter sweep tests |
| Memory growth | Resource leaks, undisposed nodes | `Performance.MEMORY_STATIC` |
| Physics jitter | Too many contacts, tunneling | `Performance.PHYSICS_3D_ACTIVE_OBJECTS` |

## Related Skills

- `.agents/skills/debug-system/SKILL.md` -- Debug overlays, F-key map, logging
- `.agents/skills/godot-audio-systems/SKILL.md` -- Bus management, spatial audio
- `.agents/skills/godot-performance-optimization/SKILL.md` -- Generic Godot optimization (community)
