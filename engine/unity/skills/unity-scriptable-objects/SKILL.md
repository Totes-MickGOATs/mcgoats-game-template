# Unity ScriptableObject Architecture

> Data-driven design patterns using ScriptableObjects for configuration, events, shared state, and runtime sets.

## What Are ScriptableObjects?

ScriptableObjects (SOs) are data containers that exist as `.asset` files in your project. Unlike MonoBehaviours, they do not live on GameObjects in scenes. They are:

- **Shared** -- multiple objects can reference the same SO instance
- **Persistent** -- survive scene loads (they are project assets, not scene objects)
- **Inspector-editable** -- designers can tweak values without touching code
- **Lightweight** -- no Transform, no GameObject overhead

```csharp
// A simple ScriptableObject
[CreateAssetMenu(fileName = "NewWeaponData", menuName = "Game/Weapon Data")]
public class WeaponData : ScriptableObject
{
    [Header("Stats")]
    [SerializeField] private string _weaponName;
    [SerializeField] private int _damage = 10;
    [SerializeField] private float _fireRate = 1f;
    [SerializeField] private float _range = 50f;

    [Header("Audio")]
    [SerializeField] private AudioClip _fireSound;
    [SerializeField] private AudioClip _reloadSound;

    [Header("Visuals")]
    [SerializeField] private GameObject _prefab;
    [SerializeField] private Sprite _icon;

    // Public read-only access
    public string WeaponName => _weaponName;
    public int Damage => _damage;
    public float FireRate => _fireRate;
    public float Range => _range;
    public AudioClip FireSound => _fireSound;
    public GameObject Prefab => _prefab;
    public Sprite Icon => _icon;
}
```

**Creating assets:** Right-click in Project window -> Create -> Game -> Weapon Data. The `[CreateAssetMenu]` attribute controls menu path and default filename.

## Use Cases Overview

| Pattern | Purpose | Example |
|---------|---------|---------|
| **Config Data** | Read-only tuning values | Weapon stats, enemy definitions, level configs |
| **Event Channels** | Decoupled event bus | `OnPlayerDied`, `OnScoreChanged`, `OnLevelComplete` |
| **Shared Variables** | Runtime-writable state visible to multiple systems | Player health, score, current weapon |
| **Runtime Sets** | Track active objects without Find/singleton | Active enemies, active projectiles, spawn points |
| **Enum Replacement** | Extensible type system | Damage types, surface types, AI states |

## Config Data Pattern

The simplest and most common use. Replace magic numbers with designer-editable assets.

```csharp
[CreateAssetMenu(menuName = "Game/Enemy Config")]
public class EnemyConfig : ScriptableObject
{
    [Header("Health")]
    [Min(1)] public int MaxHealth = 100;
    [Range(0f, 1f)] public float ArmorReduction = 0.2f;

    [Header("Movement")]
    [Min(0)] public float MoveSpeed = 5f;
    [Min(0)] public float TurnSpeed = 120f;

    [Header("Combat")]
    [Min(0)] public float AttackRange = 2f;
    [Min(0)] public float AttackCooldown = 1.5f;
    [Min(1)] public int AttackDamage = 15;

    [Header("Detection")]
    [Min(0)] public float SightRange = 20f;
    [Range(0f, 360f)] public float SightAngle = 120f;
}

// Usage: multiple enemy prefabs can share or have unique configs
public class Enemy : MonoBehaviour
{
    [SerializeField] private EnemyConfig _config;

    private int _currentHealth;

    private void Awake()
    {
        _currentHealth = _config.MaxHealth;
    }

    private void Update()
    {
        // Use _config.MoveSpeed, _config.SightRange, etc.
    }
}
```

**Key benefit:** Swap configs at runtime or in Inspector to create variants (fast zombie, tank zombie) without code changes or prefab duplication.

## Event Channel Pattern

ScriptableObjects as decoupled event buses. Publishers and subscribers reference the same SO asset -- neither needs to know about the other.

```csharp
// Base event channel (no arguments)
[CreateAssetMenu(menuName = "Events/Game Event")]
public class GameEvent : ScriptableObject
{
    private readonly List<Action> _listeners = new();

    public void Raise()
    {
        // Iterate backwards so listeners can safely unsubscribe during invocation
        for (int i = _listeners.Count - 1; i >= 0; i--)
        {
            _listeners[i]?.Invoke();
        }
    }

    public void Subscribe(Action listener) => _listeners.Add(listener);
    public void Unsubscribe(Action listener) => _listeners.Remove(listener);
}

// Generic typed event channel
public class GameEvent<T> : ScriptableObject
{
    private readonly List<Action<T>> _listeners = new();

    public void Raise(T value)
    {
        for (int i = _listeners.Count - 1; i >= 0; i--)
        {
            _listeners[i]?.Invoke(value);
        }
    }

    public void Subscribe(Action<T> listener) => _listeners.Add(listener);
    public void Unsubscribe(Action<T> listener) => _listeners.Remove(listener);
}

// Concrete typed events (needed for [CreateAssetMenu] -- generics can't have it)
[CreateAssetMenu(menuName = "Events/Int Event")]
public class IntEvent : GameEvent<int> { }

[CreateAssetMenu(menuName = "Events/Float Event")]
public class FloatEvent : GameEvent<float> { }

[CreateAssetMenu(menuName = "Events/String Event")]
public class StringEvent : GameEvent<string> { }
```

**Usage -- publisher side:**
```csharp
public class ScoreManager : MonoBehaviour
{
    [SerializeField] private IntEvent _onScoreChanged;  // Drag SO asset in Inspector

    private int _score;

    public void AddScore(int points)
    {
        _score += points;
        _onScoreChanged.Raise(_score);
    }
}
```

**Usage -- subscriber side:**
```csharp
public class ScoreDisplay : MonoBehaviour
{
    [SerializeField] private IntEvent _onScoreChanged;  // Same SO asset
    [SerializeField] private TMP_Text _scoreText;

    private void OnEnable() => _onScoreChanged.Subscribe(UpdateDisplay);
    private void OnDisable() => _onScoreChanged.Unsubscribe(UpdateDisplay);

    private void UpdateDisplay(int score)
    {
        _scoreText.text = $"Score: {score}";
    }
}
```

**Benefits over direct references:**
- ScoreManager does not know ScoreDisplay exists (and vice versa)
- Adding new listeners requires zero code changes to the publisher
- Works across scenes (SOs are project assets)
- Easy to test -- raise events manually in Inspector or tests

## Shared Variable Pattern

Runtime-writable state shared between systems without singletons or direct references.

```csharp
// Base: a ScriptableObject that holds a single value
[CreateAssetMenu(menuName = "Variables/Float Variable")]
public class FloatVariable : ScriptableObject
{
    [SerializeField] private float _initialValue;

    [System.NonSerialized] private float _runtimeValue;

    public float Value
    {
        get => _runtimeValue;
        set
        {
            if (Mathf.Approximately(_runtimeValue, value)) return;
            _runtimeValue = value;
            OnValueChanged?.Invoke(_runtimeValue);
        }
    }

    public event Action<float> OnValueChanged;

    private void OnEnable()
    {
        // Reset to initial value when entering play mode or loading
        _runtimeValue = _initialValue;
    }

#if UNITY_EDITOR
    // Allow editing in Inspector during play mode for debugging
    [SerializeField] private float _debugValue;

    private void OnValidate()
    {
        if (Application.isPlaying)
        {
            Value = _debugValue;
        }
    }
#endif
}

// Int variant
[CreateAssetMenu(menuName = "Variables/Int Variable")]
public class IntVariable : ScriptableObject
{
    [SerializeField] private int _initialValue;
    [System.NonSerialized] private int _runtimeValue;

    public int Value
    {
        get => _runtimeValue;
        set
        {
            if (_runtimeValue == value) return;
            _runtimeValue = value;
            OnValueChanged?.Invoke(_runtimeValue);
        }
    }

    public event Action<int> OnValueChanged;

    private void OnEnable() => _runtimeValue = _initialValue;
}
```

**Usage:**
```csharp
// Health system writes the variable
public class PlayerHealth : MonoBehaviour
{
    [SerializeField] private FloatVariable _playerHealthVar;
    [SerializeField] private float _maxHealth = 100f;

    private void Awake() => _playerHealthVar.Value = _maxHealth;

    public void TakeDamage(float amount)
    {
        _playerHealthVar.Value = Mathf.Max(0f, _playerHealthVar.Value - amount);
    }
}

// UI reads the variable (no reference to PlayerHealth)
public class HealthBar : MonoBehaviour
{
    [SerializeField] private FloatVariable _playerHealthVar;
    [SerializeField] private Image _fillImage;

    private void OnEnable() => _playerHealthVar.OnValueChanged += UpdateBar;
    private void OnDisable() => _playerHealthVar.OnValueChanged -= UpdateBar;

    private void UpdateBar(float health)
    {
        _fillImage.fillAmount = health / 100f;
    }
}
```

## Runtime Set Pattern

Track active instances without `FindObjectsOfType` or singletons.

```csharp
// Generic runtime set
public abstract class RuntimeSet<T> : ScriptableObject
{
    private readonly List<T> _items = new();

    public IReadOnlyList<T> Items => _items;
    public int Count => _items.Count;

    public void Add(T item)
    {
        if (!_items.Contains(item))
            _items.Add(item);
    }

    public void Remove(T item) => _items.Remove(item);

    private void OnDisable()
    {
        // Clear when exiting play mode to prevent stale references
        _items.Clear();
    }
}

// Concrete set for enemies
[CreateAssetMenu(menuName = "Runtime Sets/Enemy Set")]
public class EnemyRuntimeSet : RuntimeSet<Enemy> { }

// Enemies register/unregister themselves
public class Enemy : MonoBehaviour
{
    [SerializeField] private EnemyRuntimeSet _enemySet;

    private void OnEnable() => _enemySet.Add(this);
    private void OnDisable() => _enemySet.Remove(this);
}

// Anything can query the set without knowing about individual enemies
public class EnemyRadar : MonoBehaviour
{
    [SerializeField] private EnemyRuntimeSet _enemySet;

    private void Update()
    {
        foreach (var enemy in _enemySet.Items)
        {
            // Draw radar blip for each active enemy
        }
    }
}
```

## Enum Replacement Pattern

Use SOs instead of enums when you need extensibility without recompilation.

```csharp
// Instead of: enum DamageType { Physical, Fire, Ice, Lightning }
[CreateAssetMenu(menuName = "Game/Damage Type")]
public class DamageType : ScriptableObject
{
    [SerializeField] private string _displayName;
    [SerializeField] private Color _color = Color.white;
    [SerializeField] private GameObject _hitEffect;
    [SerializeField] private AudioClip _hitSound;

    public string DisplayName => _displayName;
    public Color Color => _color;
    public GameObject HitEffect => _hitEffect;
    public AudioClip HitSound => _hitSound;
}

// Usage -- weapon references a DamageType asset
public class Weapon : MonoBehaviour
{
    [SerializeField] private DamageType _damageType;
    [SerializeField] private int _baseDamage;

    public void Hit(IDamageable target)
    {
        target.TakeDamage(_baseDamage, _damageType);
    }
}

// Resistance system -- reference the same SO assets
public class Armor : MonoBehaviour
{
    [System.Serializable]
    public struct Resistance
    {
        public DamageType Type;
        [Range(0f, 1f)] public float Reduction;
    }

    [SerializeField] private Resistance[] _resistances;

    public float GetReduction(DamageType type)
    {
        foreach (var r in _resistances)
        {
            if (r.Type == type) return r.Reduction; // Reference comparison -- fast
        }
        return 0f;
    }
}
```

**Benefits over enums:** Adding a new damage type = create a new asset. No code changes, no recompilation, no switch statement updates.

## Nested SOs and Serialization

```csharp
// SO referencing other SOs -- works great
[CreateAssetMenu(menuName = "Game/Character Class")]
public class CharacterClass : ScriptableObject
{
    public string ClassName;
    public WeaponData StartingWeapon;       // Reference to another SO -- fine
    public List<AbilityData> Abilities;     // List of SO references -- fine
}

// GOTCHA: Creating SOs at runtime
// SOs created via ScriptableObject.CreateInstance() are NOT saved to disk.
// They exist only in memory and are lost when play mode ends.
var tempConfig = ScriptableObject.CreateInstance<WeaponData>();
// This is fine for runtime-only data, but don't expect persistence.

// GOTCHA: Nested SOs as sub-assets
// If you create a SO and add it to another SO via AssetDatabase.AddObjectToAsset,
// it becomes a sub-asset. This is editor-only and requires careful management.
```

## Editor-Only vs Runtime Data

```csharp
[CreateAssetMenu(menuName = "Game/Level Data")]
public class LevelData : ScriptableObject
{
    [Header("Runtime Data")]
    [SerializeField] private string _levelName;
    [SerializeField] private int _sceneIndex;
    [SerializeField] private int _requiredStars;

    [Header("Editor-Only Metadata")]
    #if UNITY_EDITOR
    [TextArea(3, 10)]
    [SerializeField] private string _designNotes;
    [SerializeField] private bool _isPlaytested;
    #endif

    public string LevelName => _levelName;
    public int SceneIndex => _sceneIndex;
    public int RequiredStars => _requiredStars;
}
```

## When NOT to Use ScriptableObjects

| Situation | Better Alternative | Reason |
|-----------|--------------------|--------|
| Per-instance mutable state | MonoBehaviour field | SOs are shared; mutating one affects all references |
| Large datasets (1000+ items) | JSON, SQLite, Addressables | Editor slows down with many SO assets |
| User-generated content | JSON/binary serialization | SOs require AssetDatabase (editor-only) |
| Save game data | JSON/binary file | SOs don't persist runtime changes to disk |
| Temporary runtime data | Plain C# class | No need for Unity serialization overhead |
| Configuration that changes per-build | Build scripts / defines | SOs are baked into builds |

## Database Pattern

For medium-sized collections, a single SO holding an array is cleaner than hundreds of individual SO assets.

```csharp
[CreateAssetMenu(menuName = "Database/Item Database")]
public class ItemDatabase : ScriptableObject
{
    [System.Serializable]
    public class ItemEntry
    {
        public string Id;
        public string DisplayName;
        public Sprite Icon;
        public int BasePrice;
        public ItemCategory Category;
    }

    [SerializeField] private List<ItemEntry> _items = new();

    // Runtime lookup cache (built on first access)
    private Dictionary<string, ItemEntry> _lookup;

    public ItemEntry GetItem(string id)
    {
        if (_lookup == null)
        {
            _lookup = new Dictionary<string, ItemEntry>();
            foreach (var item in _items)
                _lookup[item.Id] = item;
        }
        return _lookup.TryGetValue(id, out var entry) ? entry : null;
    }

    public IReadOnlyList<ItemEntry> AllItems => _items;
}
```

## Testing with ScriptableObjects

```csharp
// SOs are easy to create in tests -- no scene or GameObject needed
[Test]
public void WeaponDamage_WithArmorReduction_CalculatesCorrectly()
{
    // Arrange
    var fireDamage = ScriptableObject.CreateInstance<DamageType>();
    var config = ScriptableObject.CreateInstance<WeaponData>();
    // Set fields via reflection or make them public for tests

    // Act & Assert
    // ...

    // Cleanup (prevent memory leak in tests)
    Object.DestroyImmediate(fireDamage);
    Object.DestroyImmediate(config);
}
```

## SO Lifecycle Gotchas

1. **OnEnable runs in editor** -- SOs call `OnEnable` when loaded in the editor, not just in play mode. Guard runtime-only logic with `if (Application.isPlaying)`.

2. **Shared state persists in editor** -- If an SO's runtime value is changed during play mode AND the field is serialized, the change persists after exiting play mode. Use `[System.NonSerialized]` for runtime-only state.

3. **OnDisable/OnDestroy timing** -- SOs are destroyed when no longer referenced or on domain reload. Don't assume they exist forever.

4. **Addressables** -- For large projects, load SOs via Addressables instead of direct references to reduce memory footprint and enable asset bundles.
