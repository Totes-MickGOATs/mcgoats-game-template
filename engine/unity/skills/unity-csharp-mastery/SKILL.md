# Unity C# Mastery

> Patterns, conventions, and pitfalls for writing performant, idiomatic C# in Unity.

## Naming Conventions

```csharp
// PascalCase: classes, methods, properties, events, enums, public fields
public class PlayerController : MonoBehaviour
{
    // camelCase with underscore prefix: private/protected fields
    [SerializeField] private float _moveSpeed = 5f;
    [SerializeField] private int _maxHealth = 100;

    private Rigidbody _rb;
    private bool _isGrounded;

    // PascalCase: properties
    public float MoveSpeed => _moveSpeed;
    public bool IsAlive { get; private set; }

    // PascalCase: methods
    public void TakeDamage(int amount) { }

    // camelCase: local variables, parameters
    private void CalculateVelocity(float deltaTime)
    {
        var currentSpeed = _rb.linearVelocity.magnitude;
    }
}

// PascalCase: enums and their members
public enum GameState { Menu, Loading, Playing, Paused, GameOver }

// Interfaces: prefix with I
public interface IDamageable { void TakeDamage(int amount); }

// Constants: PascalCase (NOT SCREAMING_SNAKE)
public const float MaxFallSpeed = -20f;
private const int PoolInitialSize = 10;
```

**Key rules:**
- `_camelCase` for all private/protected fields (with or without `[SerializeField]`)
- `PascalCase` for everything public-facing
- `var` for local variables when type is obvious from the right side
- No Hungarian notation (`strName`, `iCount`) -- Unity codebase does not use it

## MonoBehaviour Lifecycle

Execution order matters. Mistakes here cause race conditions and null references.

```
Awake()           -- Called once when object instantiates. Set up self-references.
  |                  Called even if script is disabled. Called before Start of ANY object.
OnEnable()        -- Called every time the object/component is enabled.
  |                  Subscribe to events here.
Start()           -- Called once before the first Update. Other objects' Awake() has run.
  |                  Safe to reference other objects here.
  |
  |-- [Physics loop] --
  |   FixedUpdate()   -- Fixed timestep (default 0.02s). Physics, raycasts, forces.
  |                      May run 0, 1, or multiple times per frame.
  |
  |-- [Game loop] --
  |   Update()        -- Once per frame. Input, game logic, timers.
  |   LateUpdate()    -- Once per frame, after all Update(). Camera follow, final adjustments.
  |
OnDisable()       -- Called when object/component is disabled. Unsubscribe events here.
OnDestroy()       -- Called when object is destroyed. Final cleanup.
```

**Critical rules:**
- `Awake` for self-init (`_rb = GetComponent<Rigidbody>()`). Never reference other objects.
- `Start` for cross-object setup. All `Awake` calls are guaranteed done.
- `OnEnable`/`OnDisable` are your subscribe/unsubscribe pair. Always symmetric.
- `FixedUpdate` for physics. Never apply forces in `Update`.
- `LateUpdate` for camera. Prevents jitter from reading transform after physics moves it.

```csharp
public class Enemy : MonoBehaviour
{
    private Health _health;
    private Rigidbody _rb;

    private void Awake()
    {
        // Self-references only
        _health = GetComponent<Health>();
        _rb = GetComponent<Rigidbody>();
    }

    private void OnEnable()
    {
        _health.OnDeath += HandleDeath;
    }

    private void OnDisable()
    {
        _health.OnDeath -= HandleDeath;
    }

    private void Start()
    {
        // Safe to reference singletons, managers, other objects
        GameManager.Instance.RegisterEnemy(this);
    }
}
```

## Coroutines vs Async/Await

### Coroutines (built-in, tied to MonoBehaviour)

```csharp
private IEnumerator FadeOut(CanvasGroup group, float duration)
{
    float elapsed = 0f;
    while (elapsed < duration)
    {
        elapsed += Time.deltaTime;
        group.alpha = 1f - (elapsed / duration);
        yield return null; // Wait one frame
    }
    group.alpha = 0f;
}

// Starting and stopping
private Coroutine _fadeCoroutine;

public void StartFade()
{
    if (_fadeCoroutine != null) StopCoroutine(_fadeCoroutine);
    _fadeCoroutine = StartCoroutine(FadeOut(_canvasGroup, 1f));
}

// Common yield instructions
yield return null;                              // Next frame
yield return new WaitForSeconds(2f);            // 2 seconds (affected by Time.timeScale)
yield return new WaitForSecondsRealtime(2f);    // 2 real seconds (ignores timeScale)
yield return new WaitForFixedUpdate();          // Next physics step
yield return new WaitUntil(() => _isReady);     // Until condition is true
yield return new WaitForEndOfFrame();           // End of frame (after rendering)
```

**Coroutine pitfalls:**
- Dies when the GameObject is disabled or destroyed -- no cleanup callback
- Cannot return values
- Error handling is awkward (no try/catch across yields)
- Allocates garbage with `new WaitForSeconds` (cache them)

### UniTask (async/await, recommended for new projects)

```csharp
using Cysharp.Threading.Tasks;

private async UniTaskVoid FadeOutAsync(CanvasGroup group, float duration,
    CancellationToken ct = default)
{
    float elapsed = 0f;
    while (elapsed < duration)
    {
        ct.ThrowIfCancellationRequested();
        elapsed += Time.deltaTime;
        group.alpha = 1f - (elapsed / duration);
        await UniTask.Yield(ct);
    }
    group.alpha = 0f;
}

// Cancellation via CancellationTokenSource
private CancellationTokenSource _cts;

public void StartFade()
{
    _cts?.Cancel();
    _cts = new CancellationTokenSource();
    FadeOutAsync(_canvasGroup, 1f, _cts.Token).Forget();
}

private void OnDestroy() => _cts?.Cancel();
```

**When to use which:**
- Simple delays, visual tweens -> coroutine is fine
- Anything needing cancellation, error handling, return values -> UniTask
- Chaining multiple async operations -> UniTask (avoids callback hell)

## LINQ and GC

```csharp
// SAFE: in Awake, Start, event handlers, infrequent calls
var activeEnemies = _enemies.Where(e => e.IsAlive).ToList();
var closestItem = _items.OrderBy(i => Vector3.Distance(transform.position, i.Position)).First();

// DANGEROUS: in Update, FixedUpdate, or any per-frame path
// Each LINQ call allocates an enumerator + closure. GC spike in hot paths.
private void Update()
{
    // BAD -- allocates every frame
    var nearest = _targets.Where(t => t.IsActive).OrderBy(t => DistanceTo(t)).FirstOrDefault();

    // GOOD -- manual loop, zero allocation
    Transform nearest = null;
    float nearestDist = float.MaxValue;
    for (int i = 0; i < _targets.Count; i++)
    {
        if (!_targets[i].IsActive) continue;
        float dist = Vector3.SqrMagnitude(_targets[i].position - transform.position);
        if (dist < nearestDist)
        {
            nearestDist = dist;
            nearest = _targets[i];
        }
    }
}
```

**GC-safe hot path rules:**
- No LINQ in Update/FixedUpdate/LateUpdate
- No `foreach` on non-List collections (some allocate enumerators -- use `for` loops)
- No string concatenation (`+`) in hot paths -- use `StringBuilder` or `string.Create`
- Cache `WaitForSeconds` instances: `private static readonly WaitForSeconds Wait1s = new(1f);`
- Use `SqrMagnitude` instead of `Distance` (avoids sqrt)

## Serialization Attributes

```csharp
public class WeaponConfig : MonoBehaviour
{
    [Header("Damage Settings")]
    [Tooltip("Base damage per hit before modifiers")]
    [SerializeField] private int _baseDamage = 10;

    [Range(0.1f, 5f)]
    [SerializeField] private float _fireRate = 1f;

    [Space(10)]
    [Header("Audio")]
    [SerializeField] private AudioClip _fireSound;

    [HideInInspector]
    public int RuntimeComboMultiplier; // Serialized but hidden from Inspector

    [System.NonSerialized]
    public float TemporaryBoost; // Not serialized at all, not shown in Inspector

    [TextArea(3, 10)]
    [SerializeField] private string _description;

    [Min(0)]
    [SerializeField] private float _cooldown = 0.5f;
}
```

**Key attributes:**
- `[SerializeField]` -- expose private fields to Inspector (prefer over `public`)
- `[HideInInspector]` -- hide a public/serialized field from Inspector
- `[Header("X")]` -- section label in Inspector
- `[Range(min, max)]` -- slider in Inspector
- `[Tooltip("X")]` -- hover text in Inspector
- `[Min(0)]` -- clamp minimum value
- `[TextArea]` -- multiline text box
- `[Space(px)]` -- visual spacing in Inspector
- `[FormerlySerializedAs("oldName")]` -- rename fields without losing data

## The Null Check Trap

Unity overrides `== null` for Object-derived types. A destroyed object is "fake null" -- the C# reference still exists but Unity considers it null.

```csharp
// Setup
Destroy(gameObject);

// Next frame...
// obj is "fake null" -- C# reference exists, Unity says it's destroyed

if (obj == null) { }       // TRUE -- Unity's overloaded == catches destroyed objects
if (obj != null) { }       // FALSE -- correct
if (obj is null) { }       // FALSE! -- bypasses Unity's == operator, checks C# reference only
if (obj is not null) { }   // TRUE! -- WRONG, thinks destroyed object is alive
if (obj?.DoThing()) { }    // NullReferenceException! ?. bypasses Unity's null check

// CORRECT patterns
if (obj) { }               // Best -- implicit bool operator, handles destroyed objects
if (!obj) { }              // Best -- negated

// WRONG patterns (bypass Unity null check)
obj?.Method();             // Dangerous -- calls Method on destroyed object
obj ??= fallback;          // Dangerous -- never triggers for destroyed objects
var x = obj ?? fallback;   // Dangerous
```

**Rule:** For any Unity Object (GameObject, Component, ScriptableObject), use `if (obj)` / `if (!obj)`. Reserve `?.` and `??` for pure C# types (strings, structs, POCOs).

## Events and Delegates

```csharp
// Pattern 1: C# event with Action (RECOMMENDED for code-to-code)
public class Health : MonoBehaviour
{
    public event Action<int> OnDamaged;        // int = damage amount
    public event Action OnDeath;

    public void TakeDamage(int amount)
    {
        _currentHealth -= amount;
        OnDamaged?.Invoke(amount);
        if (_currentHealth <= 0) OnDeath?.Invoke();
    }
}

// Pattern 2: UnityEvent (for Inspector wiring -- designers drag-drop handlers)
[System.Serializable]
public class DamageEvent : UnityEvent<int> { }

public class Health : MonoBehaviour
{
    [SerializeField] private DamageEvent _onDamaged; // Configurable in Inspector
    [SerializeField] private UnityEvent _onDeath;
}

// Pattern 3: Static events (global, no reference needed)
public static class GameEvents
{
    public static event Action<int> OnScoreChanged;
    public static event Action OnGameOver;

    public static void ScoreChanged(int newScore) => OnScoreChanged?.Invoke(newScore);
    public static void GameOver() => OnGameOver?.Invoke();
}
```

**When to use which:**
- `Action`/`event` -- code-to-code, best performance, compile-time safety
- `UnityEvent` -- when designers need Inspector wiring, or for prefab configuration
- Static events -- truly global events (score, game state), but harder to test

**Always unsubscribe** in `OnDisable` or `OnDestroy`:
```csharp
private void OnEnable() => _health.OnDeath += HandleDeath;
private void OnDisable() => _health.OnDeath -= HandleDeath;
```

## readonly vs const

```csharp
// const: compile-time only, inlined at call sites, limited to primitives and strings
private const float Gravity = -9.81f;
private const string PlayerTag = "Player";

// readonly: runtime immutable, can be any type, set in declaration or constructor
private readonly List<Enemy> _pool = new();
private readonly Color _highlightColor = new(1f, 0.8f, 0f);

// static readonly: shared across instances, set once
private static readonly int AnimSpeedHash = Animator.StringToHash("Speed");
private static readonly WaitForSeconds WaitHalf = new(0.5f);
```

**Rule:** Use `const` for primitive literals that will never change. Use `static readonly` for computed values, object instances, or values that might change between builds.

**Gotcha:** `const` values are baked into consuming assemblies at compile time. If you change a `const` in Assembly A, Assembly B still sees the old value until recompiled. `static readonly` does not have this problem.

## Common Anti-Patterns

```csharp
// BAD: Find in Update
private void Update()
{
    var player = GameObject.Find("Player");           // Searches entire hierarchy every frame
    var rb = GetComponent<Rigidbody>();               // Hash lookup every frame
    var enemies = FindObjectsOfType<Enemy>();          // Scans every object in scene
    if (gameObject.CompareTag("Player")) { }          // OK -- CompareTag is fine
    if (gameObject.tag == "Player") { }               // BAD -- allocates string
}

// GOOD: Cache everything in Awake/Start
private Rigidbody _rb;
private Transform _player;

private void Awake()
{
    _rb = GetComponent<Rigidbody>();
}

private void Start()
{
    _player = GameObject.FindWithTag("Player").transform;
}

// BAD: Instantiate/Destroy in gameplay (GC spikes)
private void Fire()
{
    var bullet = Instantiate(_bulletPrefab);
    Destroy(bullet, 3f);
}

// GOOD: Object pooling
private void Fire()
{
    var bullet = _bulletPool.Get();
    bullet.Launch(_direction);
    // Return to pool instead of Destroy
}

// BAD: Camera.main in Update (calls FindWithTag internally every time in older Unity)
private void Update()
{
    transform.LookAt(Camera.main.transform); // Cached since Unity 2020.2, but still a property call
}

// GOOD: Cache it
private Camera _mainCamera;
private void Awake() => _mainCamera = Camera.main;
```

## String Handling in Hot Paths

```csharp
// BAD: string concatenation in Update (allocates new strings every frame)
private void Update()
{
    _debugText.text = "Health: " + _health + " / " + _maxHealth;
    _debugText.text = $"FPS: {1f / Time.deltaTime:F1}";  // Also allocates
}

// GOOD: StringBuilder for frequently updated text
private readonly StringBuilder _sb = new(64);

private void Update()
{
    _sb.Clear();
    _sb.Append("Health: ").Append(_health).Append(" / ").Append(_maxHealth);
    _debugText.text = _sb.ToString();
}

// GOOD: Only update when value changes
private int _lastDisplayedHealth = -1;

private void Update()
{
    if (_health != _lastDisplayedHealth)
    {
        _lastDisplayedHealth = _health;
        _healthText.text = $"Health: {_health} / {_maxHealth}";
    }
}
```

## Attribute Quick Reference

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `[SerializeField]` | Expose private field to Inspector | `[SerializeField] private float _speed;` |
| `[RequireComponent]` | Auto-add component dependency | `[RequireComponent(typeof(Rigidbody))]` |
| `[DisallowMultipleComponent]` | Prevent duplicates | Class-level attribute |
| `[ExecuteInEditMode]` | Run in editor (legacy) | Use `[ExecuteAlways]` instead |
| `[CreateAssetMenu]` | Add SO to Create menu | See ScriptableObjects skill |
| `[AddComponentMenu]` | Custom component menu path | `[AddComponentMenu("Game/Player")]` |
| `[DefaultExecutionOrder]` | Script execution priority | `[DefaultExecutionOrder(-100)]` |
| `[SelectionBase]` | Click selects this in hierarchy | Class-level, useful for root objects |
| `[ContextMenu]` | Add right-click action in Inspector | `[ContextMenu("Reset Stats")]` |
