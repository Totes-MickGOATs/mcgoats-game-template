# Unity Debugging and Profiling

Techniques for finding and fixing bugs, measuring performance, and building custom debug tools.

## Debug Logging

### Structured Logging Patterns

```csharp
// Basic logging
Debug.Log("Player spawned at position " + transform.position);
Debug.LogWarning("Health below 10% — entering critical state");
Debug.LogError("Failed to load save file: " + filePath);

// Rich text in Console
Debug.Log("<color=green><b>SPAWN</b></color> Player at " + pos);

// Context object — clicking the log selects this object in Hierarchy
Debug.Log("Damage taken: " + amount, gameObject);

// Structured tag-based logging
public static class GameLog
{
    [System.Diagnostics.Conditional("DEVELOPMENT_BUILD"),
     System.Diagnostics.Conditional("UNITY_EDITOR")]
    public static void Log(string tag, string message, Object context = null)
    {
        Debug.Log($"[<color=cyan>{tag}</color>] {message}", context);
    }

    [System.Diagnostics.Conditional("DEVELOPMENT_BUILD"),
     System.Diagnostics.Conditional("UNITY_EDITOR")]
    public static void Warn(string tag, string message, Object context = null)
    {
        Debug.LogWarning($"[{tag}] {message}", context);
    }

    public static void Error(string tag, string message, Object context = null)
    {
        // Errors always log (no conditional)
        Debug.LogError($"[{tag}] {message}", context);
    }
}

// Usage
GameLog.Log("AI", "Pathfinding complete, 23 nodes explored", gameObject);
GameLog.Warn("Physics", "Rigidbody sleeping unexpectedly");
GameLog.Error("Save", $"Corrupt save file: {path}");
```

### Conditional Compilation

```csharp
#if UNITY_EDITOR
    // Only in the Unity Editor
    Debug.Log("Editor-only debug info");
#endif

#if DEVELOPMENT_BUILD
    // In development builds (Player Settings > Development Build checkbox)
    ShowDebugOverlay();
#endif

#if UNITY_EDITOR || DEVELOPMENT_BUILD
    // Both editor and dev builds
    DrawDebugGizmos();
#endif

// Custom defines (Project Settings > Player > Scripting Define Symbols)
#if ENABLE_CHEAT_CONSOLE
    ProcessCheatCommand(input);
#endif

// Platform checks
#if UNITY_STANDALONE_WIN
    // Windows-specific code
#elif UNITY_STANDALONE_OSX
    // macOS-specific code
#elif UNITY_WEBGL
    // WebGL-specific code
#endif
```

**Important:** `[System.Diagnostics.Conditional("SYMBOL")]` is better than `#if` for methods — the entire call site is stripped, not just the method body. No allocation for string parameters when the symbol is not defined.

## Runtime Visualization

### Debug.DrawRay / Debug.DrawLine

Visible in Scene view (and Game view if Gizmos are enabled):

```csharp
private void FixedUpdate()
{
    // Visualize forward direction
    Debug.DrawRay(transform.position, transform.forward * 5f, Color.blue);

    // Visualize velocity
    Debug.DrawRay(transform.position, rb.linearVelocity, Color.red);

    // Raycast with debug visualization
    if (Physics.Raycast(transform.position, Vector3.down, out var hit, 10f))
    {
        Debug.DrawLine(transform.position, hit.point, Color.green);
        Debug.DrawRay(hit.point, hit.normal * 0.5f, Color.yellow);
    }
    else
    {
        Debug.DrawRay(transform.position, Vector3.down * 10f, Color.red);
    }
}

// Duration parameter — line persists for N seconds
Debug.DrawLine(a, b, Color.magenta, duration: 2f);

// depthTest parameter — false means visible through walls
Debug.DrawRay(pos, dir, Color.white, 0f, depthTest: false);
```

### Gizmos — Editor Visualization

```csharp
public class WaypointNode : MonoBehaviour
{
    public float radius = 2f;
    public WaypointNode nextWaypoint;

    // Always drawn when object is visible in Scene view
    private void OnDrawGizmos()
    {
        Gizmos.color = new Color(1, 1, 0, 0.3f);
        Gizmos.DrawSphere(transform.position, radius);
    }

    // Only drawn when this object is selected
    private void OnDrawGizmosSelected()
    {
        // Wireframe sphere showing trigger range
        Gizmos.color = Color.yellow;
        Gizmos.DrawWireSphere(transform.position, radius);

        // Line to next waypoint
        if (nextWaypoint != null)
        {
            Gizmos.color = Color.cyan;
            Gizmos.DrawLine(transform.position, nextWaypoint.transform.position);

            // Arrow head
            Vector3 dir = (nextWaypoint.transform.position - transform.position).normalized;
            Vector3 mid = Vector3.Lerp(transform.position, nextWaypoint.transform.position, 0.5f);
            Gizmos.DrawRay(mid, Quaternion.Euler(0, 30, 0) * -dir * 0.5f);
            Gizmos.DrawRay(mid, Quaternion.Euler(0, -30, 0) * -dir * 0.5f);
        }
    }
}
```

### Gizmo Utilities

```csharp
// Draw shapes
Gizmos.DrawCube(center, size);
Gizmos.DrawWireCube(center, size);
Gizmos.DrawSphere(center, radius);
Gizmos.DrawWireSphere(center, radius);
Gizmos.DrawLine(from, to);
Gizmos.DrawRay(origin, direction);
Gizmos.DrawFrustum(center, fov, maxRange, minRange, aspect);
Gizmos.DrawMesh(mesh, position, rotation, scale);
Gizmos.DrawIcon(position, iconName, allowScaling); // icon in Assets/Gizmos/

// Transform-aware gizmos
Gizmos.matrix = transform.localToWorldMatrix;
Gizmos.DrawWireCube(Vector3.zero, Vector3.one); // draws in local space
Gizmos.matrix = Matrix4x4.identity; // reset
```

## Unity Profiler

Open via **Window > Analysis > Profiler** (or Ctrl+7).

### Profiler Modules

| Module | What it shows |
|--------|--------------|
| **CPU Usage** | Frame time breakdown by category (scripts, rendering, physics, animation, GC) |
| **GPU Usage** | GPU frame time, shader passes |
| **Rendering** | Draw calls, triangles, vertices, set pass calls, batches |
| **Memory** | Managed heap, native allocations, GC activity |
| **Physics** | Active bodies, contacts, solver iterations, broadphase pairs |
| **Audio** | Playing sources, DSP load, channel count |
| **UI** | Canvas rebuilds, layout passes, batch count |

### CPU Usage — Reading the Timeline

The timeline shows each frame as a stacked bar. Key things to look for:

- **Tall spikes** — frame time exceeding budget (16.6ms for 60fps, 33.3ms for 30fps)
- **GC.Alloc** markers — garbage collection allocations (orange markers)
- **WaitForTargetFPS** — idle time when VSync is on (this is NOT a problem)
- **Gfx.WaitForPresent** — CPU waiting for GPU (GPU-bound)
- **Scripts** section — your C# code time

### Custom Profiler Markers

```csharp
using Unity.Profiling;

public class AIManager : MonoBehaviour
{
    static readonly ProfilerMarker s_PathfindMarker = new("AI.Pathfinding");
    static readonly ProfilerMarker s_DecisionMarker = new("AI.DecisionMaking");

    private void Update()
    {
        s_PathfindMarker.Begin();
        RunPathfinding();
        s_PathfindMarker.End();

        // Using block for auto-end
        using (s_DecisionMarker.Auto())
        {
            MakeDecisions();
        }
    }
}

// Legacy API (still works, less efficient)
private void Update()
{
    Profiler.BeginSample("MyExpensiveOperation");
    DoExpensiveThing();
    Profiler.EndSample();
}
```

### Deep Profiling

Enable via Profiler window toolbar. Records every method call with timing.

**Warning:** Deep profiling adds significant overhead (10-100x slower). Use it to find which method is slow, then switch back to normal profiling for accurate timing.

Better alternative: Add `ProfilerMarker` to suspected methods manually. Much less overhead.

## Frame Debugger

Open via **Window > Analysis > Frame Debugger**.

Click **Enable** to freeze the current frame and step through every draw call:

- See which objects are drawn in each batch
- Inspect shader properties for each draw call
- Identify why objects are NOT batching (different material, different mesh, etc.)
- See render target switches, shadow passes, post-processing steps

**Common discoveries:**
- Objects not batching because they use different material instances (use `sharedMaterial`)
- Too many shadow-casting lights
- Overdraw from transparent objects
- Unnecessary render target switches

## Memory Profiler

Install package: `com.unity.memoryprofiler`

Open via **Window > Analysis > Memory Profiler**.

### Taking Snapshots

1. Connect to target (Editor or device)
2. Click "Capture New Snapshot"
3. Inspect managed objects, native objects, and allocations
4. Compare two snapshots to find leaks

### Memory Categories

| Category | What it includes |
|----------|-----------------|
| **Managed** | C# objects on the managed heap (GC-tracked) |
| **Native** | Unity engine objects (textures, meshes, AudioClips in VRAM/RAM) |
| **Graphics** | GPU memory (render textures, buffers) |
| **Audio** | Loaded audio data |

### Common Memory Issues

- **Texture too large:** 4K textures loaded for objects that appear small on screen
- **Duplicate textures:** Same texture imported multiple times via different paths
- **Leaked GameObjects:** Instantiated but never Destroyed
- **Event listener leaks:** `+=` without corresponding `-=` prevents GC
- **Addressables not released:** `Addressables.Release()` not called after load

## Physics Debugger

Enable in Scene view: **Gizmos dropdown > Physics > Show All** (or specific options).

Shows: collision shapes, contacts, raycasts, trigger volumes.

Programmatic physics debug:

```csharp
// Visualize all raycasts
Physics.queriesHitBackfaces = false;
Physics.queriesHitTriggers = false;

// In Project Settings > Physics:
// - Contact Pairs Mode: monitor contacts
// - Enable Enhanced Determinism: for replay systems
// - Solver Iterations: increase for complex stacking (default 6)
// - Simulation Mode: Fixed Update (standard) vs Script (manual)
```

## Console Window Tips

- **Collapse** — group identical messages (shows count)
- **Clear on Play** — auto-clear when entering Play mode
- **Error Pause** — pause playback on first error
- **Stack Trace** — set per log type: None, ScriptOnly, Full
  - Use ScriptOnly for Log/Warning (faster)
  - Use Full for Error (need the context)

Filter by custom tags:
```csharp
// Use consistent prefixes so you can filter in Console search bar
Debug.Log("[AI] Pathfinding started");
Debug.Log("[Physics] Collision detected");
Debug.Log("[UI] Menu opened");
```

## Custom Debug Tools

### Runtime Debug Menu

```csharp
public class DebugMenu : MonoBehaviour
{
    private bool _showMenu;
    private bool _showFPS;
    private bool _showPhysics;
    private bool _godMode;

    private float _fps;
    private float _fpsTimer;
    private int _frameCount;

    #if UNITY_EDITOR || DEVELOPMENT_BUILD

    private void Update()
    {
        // Toggle with backtick
        if (Input.GetKeyDown(KeyCode.BackQuote))
            _showMenu = !_showMenu;

        // F-key toggles
        if (Input.GetKeyDown(KeyCode.F1)) _showFPS = !_showFPS;
        if (Input.GetKeyDown(KeyCode.F2)) _showPhysics = !_showPhysics;
        if (Input.GetKeyDown(KeyCode.F3)) _godMode = !_godMode;

        // FPS counter
        _frameCount++;
        _fpsTimer += Time.unscaledDeltaTime;
        if (_fpsTimer >= 0.5f)
        {
            _fps = _frameCount / _fpsTimer;
            _frameCount = 0;
            _fpsTimer = 0f;
        }
    }

    private void OnGUI()
    {
        if (_showFPS)
        {
            var style = new GUIStyle(GUI.skin.label) { fontSize = 24 };
            style.normal.textColor = _fps >= 55 ? Color.green :
                                     _fps >= 30 ? Color.yellow : Color.red;
            GUI.Label(new Rect(10, 10, 200, 30), $"FPS: {_fps:F0}", style);
        }

        if (_showMenu)
        {
            GUILayout.BeginArea(new Rect(10, 50, 250, 400));
            GUILayout.Box("DEBUG MENU");

            _showFPS = GUILayout.Toggle(_showFPS, "Show FPS (F1)");
            _showPhysics = GUILayout.Toggle(_showPhysics, "Show Physics (F2)");
            _godMode = GUILayout.Toggle(_godMode, "God Mode (F3)");

            if (GUILayout.Button("Kill All Enemies"))
                KillAllEnemies();
            if (GUILayout.Button("Give All Weapons"))
                GiveAllWeapons();
            if (GUILayout.Button("Teleport to Checkpoint"))
                TeleportToCheckpoint();

            GUILayout.Label($"Time Scale: {Time.timeScale:F1}");
            Time.timeScale = GUILayout.HorizontalSlider(Time.timeScale, 0f, 3f);

            GUILayout.EndArea();
        }
    }

    #endif

    private void KillAllEnemies() { /* implementation */ }
    private void GiveAllWeapons() { /* implementation */ }
    private void TeleportToCheckpoint() { /* implementation */ }
}
```

### On-Screen Stats Display

```csharp
public class StatsOverlay : MonoBehaviour
{
    [SerializeField] private bool showStats = true;

    private void OnGUI()
    {
        if (!showStats) return;

        float y = 10;
        float lineHeight = 20;

        DrawStat(ref y, lineHeight, "FPS", (1f / Time.unscaledDeltaTime).ToString("F0"));
        DrawStat(ref y, lineHeight, "Delta", (Time.deltaTime * 1000f).ToString("F1") + "ms");
        DrawStat(ref y, lineHeight, "Objects", FindObjectsByType<GameObject>(FindObjectsSortMode.None).Length.ToString());
        DrawStat(ref y, lineHeight, "Rigidbodies", FindObjectsByType<Rigidbody>(FindObjectsSortMode.None).Length.ToString());
        DrawStat(ref y, lineHeight, "Heap", (GC.GetTotalMemory(false) / (1024 * 1024)).ToString("F1") + " MB");
    }

    private void DrawStat(ref float y, float h, string label, string value)
    {
        GUI.Label(new Rect(Screen.width - 200, y, 90, h), label);
        GUI.Label(new Rect(Screen.width - 100, y, 90, h), value);
        y += h;
    }
}
```

## Common Debugging Issues

### Null Reference on Destroyed Object

```csharp
// WRONG — object may be destroyed between frames
private Enemy _target;
private void Update()
{
    float dist = Vector3.Distance(transform.position, _target.transform.position);
    // MissingReferenceException if _target was Destroy'd
}

// CORRECT — Unity overloads == for destroyed objects
private void Update()
{
    if (_target == null) { FindNewTarget(); return; }
    float dist = Vector3.Distance(transform.position, _target.transform.position);
}

// ALSO CORRECT — TryGetComponent pattern
if (_target != null && _target.TryGetComponent<Health>(out var health))
{
    health.TakeDamage(10);
}
```

### Coroutine on Disabled Object

```csharp
// Coroutines STOP when the MonoBehaviour or GameObject is disabled
// They do NOT resume when re-enabled

// WRONG
private void OnDisable()
{
    StartCoroutine(FadeOut()); // This coroutine will never run
}

// SOLUTION — use a separate always-active manager to run coroutines
GameManager.Instance.StartCoroutine(FadeOut());
```

### Awake / Start Order Issues

```csharp
// Awake order between scripts is NOT guaranteed (unless you set Script Execution Order)
// Prefer explicit initialization over relying on Awake order

// FRAGILE
public class UIManager : MonoBehaviour
{
    private void Awake() { Instance = this; }
}
public class HUD : MonoBehaviour
{
    private void Awake() { UIManager.Instance.RegisterHUD(this); } // might be null!
}

// ROBUST — use Awake for self-init, Start for cross-references
public class HUD : MonoBehaviour
{
    private void Start() { UIManager.Instance.RegisterHUD(this); }
}
```

### IL2CPP Debugging

For builds using IL2CPP (default for most platforms):

1. Enable "Development Build" and "Script Debugging" in Build Settings
2. Build and run
3. In Unity, Debug > Attach Unity Debugger > select the running player
4. Breakpoints work in Visual Studio / Rider attached to the editor or player

**Tip:** IL2CPP strips unused code. If reflection-accessed types disappear, use `[Preserve]` attribute or a `link.xml` file.
