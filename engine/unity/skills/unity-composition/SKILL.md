# Unity Composition Patterns

> Component architecture, interface-based design, dependency injection, and communication patterns -- how to structure Unity code that scales.

## Composition Over Inheritance

Unity is built on composition. GameObjects are empty containers; Components add behavior. Fight the OOP instinct to create deep inheritance hierarchies.

### The Problem with Deep Inheritance

```csharp
// BAD: Deep inheritance tree
public class Entity : MonoBehaviour { }
public class Character : Entity { }
public class Enemy : Character { }
public class FlyingEnemy : Enemy { }
public class FlyingRangedEnemy : FlyingEnemy { }
// What if you need a ground-based ranged enemy? Copy-paste or multiple inheritance (impossible).
```

### The Composition Approach

```csharp
// GOOD: Composable components
// Each behavior is a separate component. Mix and match on prefabs.

public class Health : MonoBehaviour
{
    [SerializeField] private int _maxHealth = 100;
    private int _currentHealth;

    public event Action OnDeath;
    public event Action<int> OnDamaged;

    public bool IsAlive => _currentHealth > 0;
    public float HealthPercent => (float)_currentHealth / _maxHealth;

    private void Awake() => _currentHealth = _maxHealth;

    public void TakeDamage(int amount)
    {
        if (!IsAlive) return;
        _currentHealth = Mathf.Max(0, _currentHealth - amount);
        OnDamaged?.Invoke(amount);
        if (_currentHealth <= 0) OnDeath?.Invoke();
    }
}

public class Mover : MonoBehaviour
{
    [SerializeField] private float _speed = 5f;
    private Rigidbody _rb;

    private void Awake() => _rb = GetComponent<Rigidbody>();

    public void Move(Vector3 direction)
    {
        _rb.linearVelocity = direction.normalized * _speed;
    }
}

public class Flyer : MonoBehaviour
{
    [SerializeField] private float _hoverHeight = 5f;
    [SerializeField] private float _bobAmplitude = 0.5f;
    [SerializeField] private float _bobFrequency = 1f;

    private void Update()
    {
        float bob = Mathf.Sin(Time.time * _bobFrequency) * _bobAmplitude;
        var pos = transform.position;
        pos.y = _hoverHeight + bob;
        transform.position = pos;
    }
}

public class RangedAttacker : MonoBehaviour
{
    [SerializeField] private GameObject _projectilePrefab;
    [SerializeField] private Transform _firePoint;
    [SerializeField] private float _fireRate = 1f;

    private float _lastFireTime;

    public void Fire(Vector3 direction)
    {
        if (Time.time - _lastFireTime < 1f / _fireRate) return;
        _lastFireTime = Time.time;
        var proj = Instantiate(_projectilePrefab, _firePoint.position, Quaternion.LookRotation(direction));
    }
}

// Now compose:
// Ground Melee Enemy  = Health + Mover + MeleeAttacker
// Flying Ranged Enemy = Health + Flyer + RangedAttacker
// Ground Ranged Enemy = Health + Mover + RangedAttacker
// Flying Melee Enemy  = Health + Flyer + MeleeAttacker
// Boss                = Health + Mover + MeleeAttacker + RangedAttacker + Shield
```

## Interface-Based Design

Interfaces let components interact without knowing concrete types.

```csharp
// Define contracts
public interface IDamageable
{
    void TakeDamage(int amount, DamageType type = null);
    bool IsAlive { get; }
}

public interface IHealable
{
    void Heal(int amount);
}

public interface IInteractable
{
    string InteractionPrompt { get; }
    void Interact(GameObject interactor);
}

public interface IPoolable
{
    void OnSpawn();
    void OnDespawn();
}
```

### Using Interfaces with GetComponent

```csharp
// Damage system that works with anything damageable
public class Projectile : MonoBehaviour
{
    [SerializeField] private int _damage = 10;
    [SerializeField] private DamageType _damageType;

    private void OnTriggerEnter(Collider other)
    {
        // Works for players, enemies, destructible props -- anything with IDamageable
        if (other.TryGetComponent<IDamageable>(out var damageable))
        {
            damageable.TakeDamage(_damage, _damageType);
        }
        Destroy(gameObject);
    }
}

// Interaction system
public class PlayerInteraction : MonoBehaviour
{
    [SerializeField] private float _interactRange = 2f;
    [SerializeField] private LayerMask _interactLayer;
    [SerializeField] private TMP_Text _promptText;

    private IInteractable _currentTarget;

    private void Update()
    {
        // Raycast for interactables
        if (Physics.Raycast(transform.position, transform.forward, out var hit, _interactRange, _interactLayer))
        {
            if (hit.collider.TryGetComponent<IInteractable>(out var interactable))
            {
                _currentTarget = interactable;
                _promptText.text = interactable.InteractionPrompt;
                _promptText.enabled = true;

                if (Input.GetKeyDown(KeyCode.E))
                {
                    interactable.Interact(gameObject);
                }
                return;
            }
        }

        _currentTarget = null;
        _promptText.enabled = false;
    }
}
```

### Implementing Multiple Interfaces

```csharp
// A crate that can be damaged, healed (repaired), and interacted with
public class SupplyCrate : MonoBehaviour, IDamageable, IHealable, IInteractable
{
    [SerializeField] private int _maxHealth = 50;
    private int _currentHealth;

    public bool IsAlive => _currentHealth > 0;
    public string InteractionPrompt => IsAlive ? "Open Crate" : "Broken";

    private void Awake() => _currentHealth = _maxHealth;

    public void TakeDamage(int amount, DamageType type = null)
    {
        _currentHealth = Mathf.Max(0, _currentHealth - amount);
        if (_currentHealth <= 0) Break();
    }

    public void Heal(int amount)
    {
        _currentHealth = Mathf.Min(_maxHealth, _currentHealth + amount);
    }

    public void Interact(GameObject interactor)
    {
        if (!IsAlive) return;
        // Give items to interactor
    }

    private void Break() { /* VFX, disable mesh, etc. */ }
}
```

## GetComponent Caching

`GetComponent` is a hash table lookup. Cheap once, expensive per-frame.

```csharp
// BAD: GetComponent every frame
private void Update()
{
    GetComponent<Rigidbody>().AddForce(Vector3.up); // Lookup every frame
}

// GOOD: Cache in Awake
private Rigidbody _rb;

private void Awake()
{
    _rb = GetComponent<Rigidbody>();
}

private void FixedUpdate()
{
    _rb.AddForce(Vector3.up);
}
```

### RequireComponent

Guarantees a component exists. Unity auto-adds it and prevents removal.

```csharp
[RequireComponent(typeof(Rigidbody))]
[RequireComponent(typeof(Health))]
public class EnemyController : MonoBehaviour
{
    private Rigidbody _rb;
    private Health _health;

    private void Awake()
    {
        // Guaranteed to succeed -- RequireComponent ensures they exist
        _rb = GetComponent<Rigidbody>();
        _health = GetComponent<Health>();
    }
}
```

**Limitation:** `RequireComponent` only works at add-time in the editor. It does not work with interfaces. For interface dependencies, validate in Awake:

```csharp
private void Awake()
{
    if (!TryGetComponent<IDamageable>(out _damageable))
    {
        Debug.LogError($"{name} requires an IDamageable component.", this);
        enabled = false;
    }
}
```

## Component Communication Patterns

### 1. Direct Reference (Simplest)

Components on the same GameObject or in known relationships reference each other directly.

```csharp
public class EnemyAI : MonoBehaviour
{
    private Health _health;
    private Mover _mover;

    private void Awake()
    {
        _health = GetComponent<Health>();
        _mover = GetComponent<Mover>();
    }

    private void OnEnable() => _health.OnDeath += HandleDeath;
    private void OnDisable() => _health.OnDeath -= HandleDeath;

    private void HandleDeath() => _mover.Move(Vector3.zero);
}
```

**When to use:** Components on the same GameObject or parent-child relationships. Tight coupling is acceptable here -- they are part of the same entity.

### 2. Events (Decoupled, Same Entity)

Publisher emits events; subscribers react without knowing who is listening.

```csharp
// Health doesn't know about VFX, audio, or UI
public class Health : MonoBehaviour
{
    public event Action<int> OnDamaged;
    public event Action OnDeath;
}

// Each subscriber handles its own concern
public class DamageVFX : MonoBehaviour
{
    [SerializeField] private ParticleSystem _hitParticles;
    private Health _health;

    private void Awake() => _health = GetComponent<Health>();
    private void OnEnable() => _health.OnDamaged += PlayHitEffect;
    private void OnDisable() => _health.OnDamaged -= PlayHitEffect;

    private void PlayHitEffect(int _) => _hitParticles.Play();
}

public class DamageAudio : MonoBehaviour
{
    [SerializeField] private AudioClip _hitSound;
    private Health _health;
    private AudioSource _audioSource;

    private void Awake()
    {
        _health = GetComponent<Health>();
        _audioSource = GetComponent<AudioSource>();
    }
    private void OnEnable() => _health.OnDamaged += PlayHitSound;
    private void OnDisable() => _health.OnDamaged -= PlayHitSound;

    private void PlayHitSound(int _) => _audioSource.PlayOneShot(_hitSound);
}
```

### 3. ScriptableObject Event Channels (Decoupled, Cross-Entity)

For communication between unrelated systems. See the ScriptableObjects skill for full implementation.

```csharp
// PlayerHealth raises the event
[SerializeField] private GameEvent _onPlayerDied;

private void Die() => _onPlayerDied.Raise();

// GameOverScreen subscribes (different scene, no direct reference)
[SerializeField] private GameEvent _onPlayerDied;

private void OnEnable() => _onPlayerDied.Subscribe(ShowGameOver);
private void OnDisable() => _onPlayerDied.Unsubscribe(ShowGameOver);
```

### 4. Init Method Injection

When a component needs a reference that is not on the same GameObject and cannot be found via GetComponent.

```csharp
public class HealthBar : MonoBehaviour
{
    private Health _target;
    private Image _fillImage;

    // Explicit initialization -- caller provides the dependency
    public void Init(Health target)
    {
        _target = target;
        _target.OnDamaged += UpdateBar;
    }

    private void Awake() => _fillImage = GetComponentInChildren<Image>();

    private void OnDestroy()
    {
        if (_target != null) _target.OnDamaged -= UpdateBar;
    }

    private void UpdateBar(int _)
    {
        _fillImage.fillAmount = _target.HealthPercent;
    }
}

// Spawner creates and wires up the health bar
public class EnemySpawner : MonoBehaviour
{
    [SerializeField] private GameObject _enemyPrefab;
    [SerializeField] private GameObject _healthBarPrefab;

    public void SpawnEnemy(Vector3 position)
    {
        var enemy = Instantiate(_enemyPrefab, position, Quaternion.identity);
        var healthBar = Instantiate(_healthBarPrefab, _uiCanvas.transform);
        healthBar.GetComponent<HealthBar>().Init(enemy.GetComponent<Health>());
    }
}
```

## Dependency Injection (DI Frameworks)

For large projects, manual Init methods become unwieldy. DI frameworks automate wiring.

### VContainer (Lightweight, Recommended)

```csharp
using VContainer;
using VContainer.Unity;

// Register services in a LifetimeScope (one per scene or shared)
public class GameLifetimeScope : LifetimeScope
{
    protected override void Configure(IContainerBuilder builder)
    {
        // Singleton services
        builder.Register<ScoreService>(Lifetime.Singleton);
        builder.Register<AudioService>(Lifetime.Singleton);

        // Per-resolve (new instance each time)
        builder.Register<EnemyFactory>(Lifetime.Transient);

        // MonoBehaviours in the scene
        builder.RegisterComponentInHierarchy<PlayerController>();
        builder.RegisterComponentInHierarchy<UIManager>();
    }
}

// Services receive dependencies via constructor injection
public class ScoreService
{
    private readonly AudioService _audio;

    // VContainer injects this automatically
    public ScoreService(AudioService audio)
    {
        _audio = audio;
    }

    public void AddScore(int points)
    {
        _audio.PlayScoreSound();
    }
}

// MonoBehaviours use [Inject] method (constructors don't work for MonoBehaviours)
public class ScoreDisplay : MonoBehaviour
{
    private ScoreService _scoreService;

    [Inject]
    public void Construct(ScoreService scoreService)
    {
        _scoreService = scoreService;
    }
}
```

**When to use DI:**
- 10+ services that need cross-referencing
- You want to swap implementations for testing (mock services)
- Multiple scenes need different service configurations

**When NOT to use DI:**
- Small projects (< 20 scripts) -- manual wiring is simpler
- Prototypes -- DI adds setup overhead
- If the team is unfamiliar with DI patterns

## Service Locator Pattern

A lighter alternative to full DI. A central registry that services register with and consumers query.

```csharp
public static class ServiceLocator
{
    private static readonly Dictionary<Type, object> _services = new();

    public static void Register<T>(T service) where T : class
    {
        _services[typeof(T)] = service;
    }

    public static T Get<T>() where T : class
    {
        if (_services.TryGetValue(typeof(T), out var service))
        {
            return (T)service;
        }
        Debug.LogError($"Service {typeof(T).Name} not registered.");
        return null;
    }

    public static bool TryGet<T>(out T service) where T : class
    {
        if (_services.TryGetValue(typeof(T), out var obj))
        {
            service = (T)obj;
            return true;
        }
        service = null;
        return false;
    }

    // Reset on domain reload (fast enter play mode support)
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    private static void Reset() => _services.Clear();
}

// Registration (in Awake of manager classes)
public class AudioManager : MonoBehaviour
{
    private void Awake() => ServiceLocator.Register(this);
}

// Usage
public class EnemyDeath : MonoBehaviour
{
    private void Die()
    {
        ServiceLocator.Get<AudioManager>().PlaySound("explosion");
    }
}
```

**Service Locator vs Singleton:**
- Service Locator: central registry, swappable implementations, can be cleared for tests
- Singleton: each class manages its own instance, harder to replace for testing, but simpler

## Prefab Composition

### Nested Prefabs

Prefabs containing other prefabs. Changes to inner prefabs propagate automatically.

```
EnemyBase (Prefab)
  +-- Model (child object)
  +-- Health (component)
  +-- Collider

EnemyWithWeapon (Prefab)
  +-- EnemyBase (nested prefab reference)
  +-- WeaponMount
      +-- Sword (nested prefab reference)
```

### Prefab Variants

A prefab that inherits from another, overriding specific values.

```
BaseEnemy.prefab
  Health: 100
  Speed: 5
  Color: Red

FastEnemy.prefab (variant of BaseEnemy)
  Health: 50        (overridden)
  Speed: 12         (overridden)
  Color: Red        (inherited -- changes to BaseEnemy propagate)
```

**Create a variant:** Drag a prefab into the scene, modify it, then drag it back to the Project window -> Create -> Prefab Variant.

**When to use variants vs composition:**
- **Variant:** Same entity type with different tuning (easy zombie, hard zombie)
- **Composition:** Different entity types assembled from shared components (zombie, turret, trap)

## When to Use Inheritance

Inheritance is not forbidden -- it is useful for:

```csharp
// Base class for common MonoBehaviour boilerplate
public abstract class Singleton<T> : MonoBehaviour where T : MonoBehaviour
{
    public static T Instance { get; private set; }

    protected virtual void Awake()
    {
        if (Instance != null)
        {
            Destroy(gameObject);
            return;
        }
        Instance = (T)(MonoBehaviour)this;
        DontDestroyOnLoad(gameObject);
    }
}

// Clean singleton declaration
public class AudioManager : Singleton<AudioManager>
{
    protected override void Awake()
    {
        base.Awake();
        // AudioManager-specific init
    }
}
```

```csharp
// Abstract base for similar UI screens
public abstract class MenuScreen : MonoBehaviour
{
    [SerializeField] private CanvasGroup _canvasGroup;

    public virtual void Show()
    {
        gameObject.SetActive(true);
        _canvasGroup.alpha = 1f;
        _canvasGroup.interactable = true;
        _canvasGroup.blocksRaycasts = true;
    }

    public virtual void Hide()
    {
        _canvasGroup.interactable = false;
        _canvasGroup.blocksRaycasts = false;
        gameObject.SetActive(false);
    }
}

public class MainMenuScreen : MenuScreen
{
    public override void Show()
    {
        base.Show();
        // Refresh leaderboard, etc.
    }
}
```

**Rule of thumb:** Use inheritance for framework-level base classes (singletons, UI screens, state bases). Use composition for gameplay entities (enemies, weapons, interactables).

## Architecture Decision Guide

| Situation | Pattern |
|-----------|---------|
| Components on same GameObject | Direct reference via GetComponent (cached) |
| Parent-child components | GetComponentInChildren / GetComponentInParent |
| Same entity, loose coupling | C# events (subscribe in OnEnable, unsubscribe in OnDisable) |
| Cross-entity, same scene | ScriptableObject event channels or direct reference |
| Cross-scene | ScriptableObject event channels or Service Locator |
| Global services (audio, input) | Singleton or Service Locator |
| Large project, testability | DI framework (VContainer) |
| Spawned objects need references | Init method injection |
| Entity variants (easy/hard enemy) | Prefab variants |
| Entity types (enemy/turret/trap) | Component composition on prefabs |
