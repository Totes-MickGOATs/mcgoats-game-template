# Unity Performance Optimization

Practical techniques for keeping your game running at target frame rate. Always profile first — never optimize blindly.

## Profiling Workflow

1. **Identify the bottleneck** — Is it CPU, GPU, or memory? Check Profiler.
2. **Measure** — Get a baseline number (ms per frame, draw calls, memory).
3. **Optimize** — Apply the appropriate technique.
4. **Verify** — Re-measure. Did it actually improve? By how much?
5. **Repeat** — Go back to step 1.

**Frame budgets:**

| Target FPS | Budget per Frame |
|------------|-----------------|
| 30 fps | 33.3 ms |
| 60 fps | 16.6 ms |
| 90 fps (VR) | 11.1 ms |
| 120 fps | 8.3 ms |

## Batching and Draw Call Reduction

Every draw call has CPU overhead. Reducing draw calls is often the biggest performance win.

### Static Batching

Combines static meshes at build time into larger meshes per material.

- Mark non-moving objects as **Static** in Inspector (or just "Batching Static")
- Increases memory (stores combined mesh) but reduces draw calls dramatically
- Objects must share the same material

### Dynamic Batching

Automatically batches small moving meshes at runtime.

- Only works for meshes under 300 vertices (with specific attribute constraints)
- Not reliable — many conditions can break it
- Generally prefer GPU Instancing or SRP Batcher instead

### GPU Instancing

Renders multiple copies of the same mesh+material in one draw call.

```csharp
// Enable on material: Inspector > Enable GPU Instancing checkbox
// Or in code:
material.enableInstancing = true;
```

Works with: same mesh, same material, different transforms and per-instance properties.

```csharp
// Per-instance properties via MaterialPropertyBlock (does NOT break batching)
MaterialPropertyBlock props = new MaterialPropertyBlock();
props.SetColor("_Color", Random.ColorHSV());
renderer.SetPropertyBlock(props);
```

### SRP Batcher (URP/HDRP)

The SRP Batcher reduces CPU overhead of draw calls by caching shader variant states.

- Enabled by default in URP/HDRP
- Works with any mesh, as long as the shader is SRP Batcher compatible
- Check compatibility: select shader > Inspector shows "SRP Batcher: compatible"
- To make a shader compatible: use CBUFFER for all material properties

### Material Sharing

```csharp
// WRONG — creates a unique material instance, breaks batching
renderer.material.color = Color.red; // .material creates a clone

// CORRECT for read — doesn't create a clone
Color c = renderer.sharedMaterial.color;

// CORRECT for per-instance variation — use MaterialPropertyBlock
var block = new MaterialPropertyBlock();
block.SetColor("_BaseColor", Color.red);
renderer.SetPropertyBlock(block);
```

### Texture Atlases

Combine multiple small textures into one atlas. Objects using different sprites from the same atlas can batch together.

- Unity's Sprite Atlas (2D)
- Manual atlas for 3D: pack textures in DCC tool, UV-map accordingly
- TextMeshPro uses font atlas automatically

## LOD Groups

Reduce polygon count for distant objects:

```
LOD 0: Full detail    — 0-20% screen height → 5000 tris
LOD 1: Medium detail  — 20-50% → 2000 tris
LOD 2: Low detail     — 50-80% → 500 tris
Culled                 — 80-100% → not rendered
```

Setup: Add LODGroup component, assign mesh renderers to each LOD level.

**Cross-fade:** Enable for smooth transitions (uses dithering). Small GPU cost but looks much better.

**LOD Bias:** Project Settings > Quality > LOD Bias. Higher = use higher LOD longer. 1.0 = default, 2.0 = double quality distance.

## Occlusion Culling

Skip rendering objects hidden behind other objects.

1. Mark occluders (walls, buildings) as **Occluder Static**
2. Mark occludees (everything) as **Occludee Static**
3. Bake: Window > Rendering > Occlusion Culling > Bake
4. Tune cell size for accuracy vs bake time

**When to use:** Dense indoor environments, urban areas with buildings. Less useful for open worlds with few occluders.

**Frustum culling** is free and automatic — only objects in the camera's view are rendered. Occlusion culling is additional.

## Object Pooling

Avoid Instantiate/Destroy overhead by reusing objects:

```csharp
// Unity's built-in ObjectPool<T> (2021.1+)
using UnityEngine.Pool;

public class BulletPool : MonoBehaviour
{
    [SerializeField] private GameObject bulletPrefab;

    private ObjectPool<GameObject> _pool;

    private void Awake()
    {
        _pool = new ObjectPool<GameObject>(
            createFunc: () => Instantiate(bulletPrefab),
            actionOnGet: bullet => bullet.SetActive(true),
            actionOnRelease: bullet => bullet.SetActive(false),
            actionOnDestroy: bullet => Destroy(bullet),
            collectionCheck: false,
            defaultCapacity: 50,
            maxSize: 200
        );
    }

    public GameObject GetBullet()
    {
        return _pool.Get();
    }

    public void ReturnBullet(GameObject bullet)
    {
        _pool.Release(bullet);
    }
}
```

### Generic Pool Pattern (pre-2021)

```csharp
public class GenericPool<T> where T : Component
{
    private readonly Queue<T> _available = new();
    private readonly T _prefab;
    private readonly Transform _parent;

    public GenericPool(T prefab, int initialSize, Transform parent = null)
    {
        _prefab = prefab;
        _parent = parent;

        for (int i = 0; i < initialSize; i++)
        {
            var obj = Object.Instantiate(prefab, parent);
            obj.gameObject.SetActive(false);
            _available.Enqueue(obj);
        }
    }

    public T Get()
    {
        T obj = _available.Count > 0
            ? _available.Dequeue()
            : Object.Instantiate(_prefab, _parent);

        obj.gameObject.SetActive(true);
        return obj;
    }

    public void Release(T obj)
    {
        obj.gameObject.SetActive(false);
        _available.Enqueue(obj);
    }
}
```

## Garbage Collection Optimization

GC spikes cause frame hitches. The goal: zero allocations in hot paths (Update, FixedUpdate).

### Common Allocation Sources and Fixes

```csharp
// ALLOCATES — string concatenation
void Update()
{
    scoreText.text = "Score: " + score; // creates new string every frame
}

// FIX — cache or use StringBuilder
private readonly StringBuilder _sb = new(32);
void Update()
{
    _sb.Clear();
    _sb.Append("Score: ").Append(score);
    scoreText.text = _sb.ToString();
}

// ALLOCATES — LINQ in hot path
void Update()
{
    var enemies = allEntities.Where(e => e.IsEnemy).ToList(); // allocates
}

// FIX — manual loop, reuse list
private readonly List<Entity> _enemyCache = new(64);
void Update()
{
    _enemyCache.Clear();
    for (int i = 0; i < allEntities.Count; i++)
    {
        if (allEntities[i].IsEnemy) _enemyCache.Add(allEntities[i]);
    }
}

// ALLOCATES — foreach on some collections (boxing)
foreach (var item in myHashSet) { } // may box enumerator

// FIX — use for loop where possible, or List<T> (no boxing)
for (int i = 0; i < myList.Count; i++) { }

// ALLOCATES — GetComponent every frame
void Update()
{
    var rb = GetComponent<Rigidbody>(); // allocates if done repeatedly
}

// FIX — cache in Awake/Start
private Rigidbody _rb;
void Awake() { _rb = GetComponent<Rigidbody>(); }

// ALLOCATES — new arrays/lists
void Update()
{
    var hits = Physics.RaycastAll(ray); // allocates array
}

// FIX — NonAlloc variants
private readonly RaycastHit[] _hitBuffer = new RaycastHit[32];
void Update()
{
    int count = Physics.RaycastNonAlloc(ray, _hitBuffer);
    for (int i = 0; i < count; i++) { /* use _hitBuffer[i] */ }
}

// ALLOCATES — closures/lambdas capturing variables
void Update()
{
    int id = entityId;
    DoAsync(() => ProcessEntity(id)); // captures 'id', allocates closure
}

// FIX — avoid lambdas in hot paths, use direct method references
```

### Incremental GC

Unity 2019.1+ supports incremental GC. Enable in Project Settings > Player > Configuration.

Spreads GC work across multiple frames instead of one big spike. Recommended for all projects.

## Physics Optimization

### Collision Matrix

In Project Settings > Physics, uncheck layer pairs that never collide:

```
             Terrain  Vehicles  Projectiles  UI
Terrain         x
Vehicles        x        x
Projectiles     x        x
UI
```

This reduces broadphase pair checks significantly.

### Simulation Settings

```
Fixed Timestep: 0.02 (50 Hz) — standard
                0.01 (100 Hz) — high precision (vehicles, fighting games)
                0.04 (25 Hz)  — low precision (mobile, casual)

Solver Iterations: 6 (default) — increase for stacking/joints
Solver Velocity Iterations: 1 — increase for fast-moving objects

Auto Sync Transforms: OFF (default) — only sync when Physics.SyncTransforms() or FixedUpdate
```

### Rigidbody Best Practices

- Use `Rigidbody.isKinematic = true` for objects that move but don't need physics simulation
- `Rigidbody.Sleep()` — manually sleep objects that have settled
- Reduce collider complexity: prefer box/sphere/capsule over mesh colliders
- Convex mesh colliders are much cheaper than concave
- Avoid moving static colliders (objects without Rigidbody) — this rebuilds the physics broadphase

## UI Optimization

### Canvas Splitting

Every change to a Canvas element dirties the ENTIRE canvas batch. Split canvases by update frequency:

```
Canvas (Static HUD)        — health bar frame, minimap border, rarely changes
Canvas (Dynamic HUD)       — health fill, score counter, changes every frame
Canvas (Floating Text)     — damage numbers, frequent create/destroy
```

### Raycast Target

Disable **Raycast Target** on every Image/Text that is not interactive:

```csharp
// In code
image.raycastTarget = false;
textMesh.raycastTarget = false;
```

This is the most common Unity UI performance mistake. Background images, decorative text, and icons should never have raycast enabled.

### Canvas Group for Visibility

```csharp
// WRONG — disabling Canvas rebuilds on re-enable
canvas.enabled = false; // triggers full rebuild when re-enabled

// BETTER — CanvasGroup alpha for show/hide
canvasGroup.alpha = 0f;           // invisible
canvasGroup.blocksRaycasts = false; // non-interactive
canvasGroup.interactable = false;

// BEST for frequently toggling — just move off-screen or use CanvasGroup
```

## Texture Optimization

| Platform | Recommended Format | Notes |
|----------|--------------------|-------|
| Desktop | BC7 (quality) / DXT5 (performance) | BC7 is higher quality at same size |
| Mobile (Android) | ASTC 6x6 (quality) / ETC2 (compatibility) | ASTC preferred for modern devices |
| Mobile (iOS) | ASTC 6x6 | Standard for iOS |
| WebGL | DXT5 / ETC2 | DXT for desktop browsers, ETC2 for mobile |

### Texture Settings

- **Max Size:** Match actual usage. A texture shown as 256px on screen does not need 4096px.
- **Mipmaps:** Enable for 3D objects (reduces aliasing and improves cache performance). Disable for UI sprites.
- **Read/Write Enabled:** OFF unless you need CPU access. Doubles memory.
- **Generate Mipmaps > Streaming:** Enable for large worlds. Loads mip levels on demand.

## Mesh Optimization

- **Polygon budgets:** Set per-project. e.g., hero character 10K-50K tris, environment props 100-2K tris
- **Mesh Compression:** Low/Medium/High in import settings. Reduces disk/download size.
- **Read/Write Enabled:** OFF unless modifying mesh at runtime. Halves mesh memory.
- **Optimize Mesh Data:** Enable in Player Settings. Strips unused vertex attributes.
- **Vertex Compression:** Enable in Player Settings. Uses half-precision where possible.

## Shader Optimization

### Variant Stripping

Shaders compile into many variants (keywords x passes x stages). Strip unused ones:

```csharp
// In IPreprocessShaders implementation
public void OnProcessShader(Shader shader, ShaderSnippetData snippet,
    IList<ShaderCompilerData> data)
{
    for (int i = data.Count - 1; i >= 0; i--)
    {
        // Strip variants with keywords you never use
        if (data[i].shaderKeywordSet.IsEnabled(
            new ShaderKeyword("_DETAIL_MULX2")))
        {
            data.RemoveAt(i);
        }
    }
}
```

### Keyword Limits

Unity has a global limit of ~256 local shader keywords and ~384 global keywords. Keep keyword usage minimal.

### Mobile-Friendly Shader Tips

- Use `half` precision where possible (color, UV, normals)
- Avoid branching in fragment shaders
- Minimize texture samples per fragment
- Use `DisableBatching` tag sparingly

## Async Operations

### Addressables

```csharp
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

// Async load
var handle = Addressables.LoadAssetAsync<GameObject>("Prefabs/Enemy");
handle.Completed += op =>
{
    if (op.Status == AsyncOperationStatus.Succeeded)
    {
        Instantiate(op.Result);
    }
};

// Don't forget to release
Addressables.Release(handle);
```

### Async Scene Loading

```csharp
public async void LoadGameScene()
{
    var op = SceneManager.LoadSceneAsync("GameScene");
    op.allowSceneActivation = false;

    while (op.progress < 0.9f)
    {
        loadingBar.value = op.progress / 0.9f;
        await Task.Yield();
    }

    loadingBar.value = 1f;
    await Task.Delay(500); // brief pause
    op.allowSceneActivation = true;
}
```

### Job System (Burst-Compiled Parallel Work)

```csharp
using Unity.Jobs;
using Unity.Collections;
using Unity.Burst;

[BurstCompile]
public struct DistanceJob : IJobParallelFor
{
    [ReadOnly] public NativeArray<Vector3> Positions;
    public Vector3 Target;
    public NativeArray<float> Results;

    public void Execute(int index)
    {
        Results[index] = Vector3.Distance(Positions[index], Target);
    }
}

// Schedule
var positions = new NativeArray<Vector3>(1000, Allocator.TempJob);
var results = new NativeArray<float>(1000, Allocator.TempJob);
// ... fill positions ...

var job = new DistanceJob
{
    Positions = positions,
    Target = playerPos,
    Results = results
};

JobHandle handle = job.Schedule(1000, 64); // batch size 64
handle.Complete();

// Use results...
positions.Dispose();
results.Dispose();
```

## Quick Wins Checklist

- [ ] Disable Raycast Target on non-interactive UI elements
- [ ] Split canvases by update frequency
- [ ] Mark non-moving objects as Static
- [ ] Enable GPU Instancing on shared materials
- [ ] Use NonAlloc physics queries
- [ ] Cache GetComponent results
- [ ] Set appropriate texture Max Size
- [ ] Disable Read/Write on textures and meshes you don't modify at runtime
- [ ] Configure collision matrix to skip impossible layer pairs
- [ ] Enable Incremental GC
- [ ] Use object pooling for frequently spawned/despawned objects
- [ ] Disable mipmaps on UI textures
- [ ] Profile before optimizing — measure, don't guess
