# Unity Testing Patterns

Testing in Unity using the Unity Test Framework (based on NUnit). This project uses TDD: write tests first, run them, confirm red, implement, confirm green, commit.

## Test Framework Setup

Unity Test Framework comes pre-installed. Tests live in assembly definitions:

```
Assets/
  Tests/
    EditMode/
      Game.Tests.EditMode.asmdef    ← Editor platform only
      TestPlayerStats.cs
      TestInventorySystem.cs
    PlayMode/
      Game.Tests.PlayMode.asmdef    ← Any platform (includes Editor)
      TestPlayerMovement.cs
      TestSceneLoading.cs
```

### Edit Mode Assembly Definition

```json
{
    "name": "Game.Tests.EditMode",
    "rootNamespace": "",
    "references": [
        "Game.Runtime",
        "UnityEngine.TestRunner",
        "UnityEditor.TestRunner"
    ],
    "includePlatforms": ["Editor"],
    "defineConstraints": ["UNITY_INCLUDE_TESTS"],
    "autoReferenced": false
}
```

### Play Mode Assembly Definition

```json
{
    "name": "Game.Tests.PlayMode",
    "rootNamespace": "",
    "references": [
        "Game.Runtime",
        "UnityEngine.TestRunner",
        "UnityEditor.TestRunner"
    ],
    "includePlatforms": [],
    "defineConstraints": ["UNITY_INCLUDE_TESTS"],
    "autoReferenced": false
}
```

**Key difference:** Edit Mode tests set `includePlatforms: ["Editor"]`. Play Mode tests leave it empty (any platform).

## Edit Mode Tests — Pure Logic

Edit Mode tests run without entering Play mode. They are fast and ideal for testing:

- Pure C# classes and structs
- ScriptableObject data
- Serialization / deserialization
- Math utilities
- State machines (logic only)
- Data validation

```csharp
using NUnit.Framework;

[TestFixture]
public class TestPlayerStats
{
    private PlayerStats _stats;

    [SetUp]
    public void SetUp()
    {
        _stats = new PlayerStats(maxHealth: 100, maxStamina: 50);
    }

    [Test]
    public void InitialHealth_EqualsMaxHealth()
    {
        Assert.AreEqual(100, _stats.CurrentHealth);
    }

    [Test]
    public void TakeDamage_ReducesHealth()
    {
        _stats.TakeDamage(30);
        Assert.AreEqual(70, _stats.CurrentHealth);
    }

    [Test]
    public void TakeDamage_ClampsAtZero()
    {
        _stats.TakeDamage(999);
        Assert.AreEqual(0, _stats.CurrentHealth);
    }

    [Test]
    public void TakeDamage_NegativeAmount_ThrowsException()
    {
        Assert.Throws<System.ArgumentException>(() => _stats.TakeDamage(-10));
    }

    [Test]
    public void Heal_RestoresHealth()
    {
        _stats.TakeDamage(50);
        _stats.Heal(20);
        Assert.AreEqual(70, _stats.CurrentHealth);
    }

    [Test]
    public void Heal_DoesNotExceedMax()
    {
        _stats.TakeDamage(10);
        _stats.Heal(999);
        Assert.AreEqual(100, _stats.CurrentHealth);
    }

    [Test]
    public void IsDead_WhenHealthIsZero()
    {
        _stats.TakeDamage(100);
        Assert.IsTrue(_stats.IsDead);
    }

    [Test]
    public void IsDead_FalseWhenHealthAboveZero()
    {
        _stats.TakeDamage(99);
        Assert.IsFalse(_stats.IsDead);
    }
}
```

### Testing ScriptableObjects

```csharp
[TestFixture]
public class TestWeaponData
{
    [Test]
    public void DPS_CalculatedCorrectly()
    {
        var weapon = ScriptableObject.CreateInstance<WeaponData>();
        weapon.damage = 25;
        weapon.fireRate = 2f; // shots per second

        Assert.AreApproximatelyEqual(50f, weapon.DPS, 0.001f);

        Object.DestroyImmediate(weapon);
    }

    [Test]
    public void WeaponData_Serialization_RoundTrips()
    {
        var weapon = ScriptableObject.CreateInstance<WeaponData>();
        weapon.damage = 42;
        weapon.weaponName = "Blaster";

        string json = JsonUtility.ToJson(weapon);
        var restored = ScriptableObject.CreateInstance<WeaponData>();
        JsonUtility.FromJsonOverwrite(json, restored);

        Assert.AreEqual(42, restored.damage);
        Assert.AreEqual("Blaster", restored.weaponName);

        Object.DestroyImmediate(weapon);
        Object.DestroyImmediate(restored);
    }
}
```

## Play Mode Tests — Runtime Behavior

Play Mode tests run inside a real game loop. They test MonoBehaviours, physics, coroutines, and scene interactions.

```csharp
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestUtils;
using System.Collections;

[TestFixture]
public class TestPlayerMovement
{
    private GameObject _playerObj;
    private PlayerMovement _player;
    private Rigidbody _rb;

    [SetUp]
    public void SetUp()
    {
        _playerObj = new GameObject("TestPlayer");
        _rb = _playerObj.AddComponent<Rigidbody>();
        _rb.useGravity = false; // isolate horizontal movement
        _player = _playerObj.AddComponent<PlayerMovement>();
        _player.moveSpeed = 5f;
    }

    [TearDown]
    public void TearDown()
    {
        Object.Destroy(_playerObj);
    }

    [UnityTest]
    public IEnumerator MoveForward_ChangesPosition()
    {
        Vector3 startPos = _playerObj.transform.position;

        // Simulate input
        _player.SetMoveInput(Vector3.forward);

        // Wait several physics frames
        for (int i = 0; i < 10; i++)
            yield return new WaitForFixedUpdate();

        Vector3 endPos = _playerObj.transform.position;
        Assert.Greater(endPos.z, startPos.z, "Player should move forward on Z axis");
    }

    [UnityTest]
    public IEnumerator NoInput_PlayerStaysStill()
    {
        Vector3 startPos = _playerObj.transform.position;
        _player.SetMoveInput(Vector3.zero);

        yield return new WaitForFixedUpdate();
        yield return new WaitForFixedUpdate();

        Assert.AreEqual(startPos, _playerObj.transform.position);
    }

    [UnityTest]
    public IEnumerator Sprint_IncreasesSpeed()
    {
        _player.SetMoveInput(Vector3.forward);
        _player.SetSprint(false);
        yield return new WaitForFixedUpdate();
        float normalSpeed = _rb.linearVelocity.magnitude;

        _player.SetSprint(true);
        for (int i = 0; i < 10; i++)
            yield return new WaitForFixedUpdate();

        float sprintSpeed = _rb.linearVelocity.magnitude;
        Assert.Greater(sprintSpeed, normalSpeed);
    }
}
```

### Testing Physics Interactions

```csharp
[UnityTest]
public IEnumerator Projectile_DestroysOnImpact()
{
    // Create wall
    var wall = GameObject.CreatePrimitive(PrimitiveType.Cube);
    wall.transform.position = new Vector3(0, 0, 5);
    wall.AddComponent<Rigidbody>().isKinematic = true;

    // Create projectile
    var projectileObj = new GameObject("Projectile");
    projectileObj.transform.position = Vector3.zero;
    var rb = projectileObj.AddComponent<Rigidbody>();
    rb.useGravity = false;
    var collider = projectileObj.AddComponent<SphereCollider>();
    var projectile = projectileObj.AddComponent<Projectile>();
    projectile.destroyOnImpact = true;

    // Fire toward wall
    rb.linearVelocity = Vector3.forward * 50f;

    // Wait for collision
    yield return new WaitForSeconds(0.5f);

    // Projectile should be destroyed
    Assert.IsTrue(projectileObj == null, "Projectile should be destroyed after impact");

    Object.Destroy(wall);
}
```

### Scene-Based Tests

```csharp
using UnityEngine.SceneManagement;

[UnityTest]
public IEnumerator GameScene_SpawnsPlayer()
{
    SceneManager.LoadScene("GameScene", LoadSceneMode.Single);
    yield return null; // wait one frame for scene load
    yield return null; // extra frame for Start() calls

    var player = GameObject.FindWithTag("Player");
    Assert.IsNotNull(player, "Player should be spawned in GameScene");
}

[UnityTest]
public IEnumerator MainMenu_PlayButton_LoadsGame()
{
    SceneManager.LoadScene("MainMenu", LoadSceneMode.Single);
    yield return null;
    yield return null;

    var playButton = GameObject.Find("PlayButton").GetComponent<Button>();
    Assert.IsNotNull(playButton);

    // Simulate click
    playButton.onClick.Invoke();

    // Wait for scene transition
    yield return new WaitForSeconds(2f);

    Assert.AreEqual("GameScene", SceneManager.GetActiveScene().name);
}
```

## Assertions Reference

### NUnit Assertions

```csharp
// Equality
Assert.AreEqual(expected, actual);
Assert.AreNotEqual(unexpected, actual);

// Boolean
Assert.IsTrue(condition);
Assert.IsFalse(condition);

// Null
Assert.IsNull(obj);
Assert.IsNotNull(obj);

// Comparison
Assert.Greater(bigger, smaller);
Assert.Less(smaller, bigger);
Assert.GreaterOrEqual(a, b);

// Collections
Assert.Contains(item, collection);
CollectionAssert.AreEqual(expected, actual);       // same order
CollectionAssert.AreEquivalent(expected, actual);  // same items, any order
CollectionAssert.IsEmpty(collection);

// Exceptions
Assert.Throws<ArgumentException>(() => SomeMethod());
Assert.DoesNotThrow(() => SomeMethod());

// Constraint-based (more expressive)
Assert.That(value, Is.EqualTo(42));
Assert.That(value, Is.GreaterThan(0).And.LessThan(100));
Assert.That(list, Has.Count.EqualTo(5));
Assert.That(text, Does.Contain("error"));
Assert.That(value, Is.InRange(0f, 1f));
```

### Unity-Specific Assertions

```csharp
// Float comparison with tolerance (essential for physics)
Assert.AreApproximatelyEqual(expected, actual, tolerance);
// Default tolerance is 0.00001f

// Log assertions — verify Debug.Log was called
LogAssert.Expect(LogType.Error, "Expected error message");
LogAssert.Expect(LogType.Warning, new Regex("pattern.*match"));
// Test fails if the expected log is NOT emitted

// Ignore specific logs that would fail the test
LogAssert.ignoreFailingMessages = true; // use sparingly
```

## Setup and Teardown

```csharp
[TestFixture]
public class TestInventory
{
    private static ItemDatabase _database; // shared across all tests

    [OneTimeSetUp]
    public void OneTimeSetUp()
    {
        // Runs once before ALL tests in this fixture
        _database = ScriptableObject.CreateInstance<ItemDatabase>();
        _database.Initialize();
    }

    [OneTimeTearDown]
    public void OneTimeTearDown()
    {
        // Runs once after ALL tests
        Object.DestroyImmediate(_database);
    }

    [SetUp]
    public void SetUp()
    {
        // Runs before EACH test
    }

    [TearDown]
    public void TearDown()
    {
        // Runs after EACH test — clean up GameObjects, etc.
    }
}
```

## Mocking and Dependency Injection

Unity is not compatible with IL2CPP mocking frameworks (Moq, NSubstitute). Use interface-based manual stubs:

```csharp
// Production interface
public interface IInputProvider
{
    Vector2 GetMovement();
    bool GetJump();
    bool GetAttack();
}

// Production implementation
public class GameInputProvider : IInputProvider
{
    public Vector2 GetMovement() => new Vector2(
        Input.GetAxis("Horizontal"), Input.GetAxis("Vertical"));
    public bool GetJump() => Input.GetButtonDown("Jump");
    public bool GetAttack() => Input.GetButtonDown("Fire1");
}

// Test stub
public class MockInputProvider : IInputProvider
{
    public Vector2 Movement { get; set; }
    public bool Jump { get; set; }
    public bool Attack { get; set; }

    public Vector2 GetMovement() => Movement;
    public bool GetJump() => Jump;
    public bool GetAttack() => Attack;
}

// System under test accepts the interface
public class PlayerController : MonoBehaviour
{
    private IInputProvider _input;

    public void Initialize(IInputProvider input) => _input = input;

    private void Update()
    {
        var move = _input.GetMovement();
        // ... use movement
    }
}

// Test
[UnityTest]
public IEnumerator Player_MovesWithInput()
{
    var player = new GameObject().AddComponent<PlayerController>();
    var mockInput = new MockInputProvider { Movement = new Vector2(1, 0) };
    player.Initialize(mockInput);

    yield return null; // wait one frame for Update

    // Assert player moved right
    Assert.Greater(player.transform.position.x, 0);

    Object.Destroy(player.gameObject);
}
```

### Event/Signal Testing

```csharp
[Test]
public void OnDeath_Event_Fires_When_Health_Reaches_Zero()
{
    var stats = new PlayerStats(maxHealth: 100);
    bool deathFired = false;

    stats.OnDeath += () => deathFired = true;
    stats.TakeDamage(100);

    Assert.IsTrue(deathFired, "OnDeath event should fire when health reaches 0");
}

[Test]
public void OnDeath_Event_DoesNotFire_When_Alive()
{
    var stats = new PlayerStats(maxHealth: 100);
    bool deathFired = false;

    stats.OnDeath += () => deathFired = true;
    stats.TakeDamage(50);

    Assert.IsFalse(deathFired, "OnDeath should not fire when health is above 0");
}
```

## Parameterized Tests

```csharp
[TestCase(100, 30, 70)]
[TestCase(100, 100, 0)]
[TestCase(100, 0, 100)]
[TestCase(50, 50, 0)]
public void TakeDamage_ReducesCorrectAmount(int maxHp, int damage, int expected)
{
    var stats = new PlayerStats(maxHealth: maxHp);
    stats.TakeDamage(damage);
    Assert.AreEqual(expected, stats.CurrentHealth);
}

[TestCase("Sword", 10, 2f, 20f)]
[TestCase("Bow", 5, 3f, 15f)]
public void DPS_Calculation(string name, int damage, float rate, float expectedDps)
{
    var weapon = ScriptableObject.CreateInstance<WeaponData>();
    weapon.damage = damage;
    weapon.fireRate = rate;

    Assert.AreApproximatelyEqual(expectedDps, weapon.DPS, 0.01f);

    Object.DestroyImmediate(weapon);
}
```

## Testing Async and Coroutines

```csharp
[UnityTest]
public IEnumerator Ability_Cooldown_BlocksReuse()
{
    var ability = new GameObject().AddComponent<FireballAbility>();
    ability.cooldownDuration = 1f;

    // First use should succeed
    bool firstUse = ability.TryActivate();
    Assert.IsTrue(firstUse);

    // Immediate second use should fail (on cooldown)
    bool secondUse = ability.TryActivate();
    Assert.IsFalse(secondUse);

    // Wait for cooldown
    yield return new WaitForSeconds(1.1f);

    // Now it should work again
    bool thirdUse = ability.TryActivate();
    Assert.IsTrue(thirdUse);

    Object.Destroy(ability.gameObject);
}
```

## Code Coverage

Install: `com.unity.testtools.codecoverage`

Enable in Window > Analysis > Code Coverage:
- Enable Code Coverage recording
- Select assemblies to include (e.g., `Game.Runtime`)
- Run tests
- Generate HTML report

## CI Integration

Run tests in batch mode for CI/CD pipelines:

```bash
# Edit Mode tests
Unity -batchmode -nographics -runTests \
  -testPlatform EditMode \
  -testResults ./results/editmode-results.xml \
  -projectPath . \
  -logFile ./results/unity.log

# Play Mode tests
Unity -batchmode -nographics -runTests \
  -testPlatform PlayMode \
  -testResults ./results/playmode-results.xml \
  -projectPath . \
  -logFile ./results/unity.log
```

Exit code 0 = all passed, non-zero = failures.

### GitHub Actions Example

```yaml
- name: Run Edit Mode Tests
  uses: game-ci/unity-test-runner@v4
  with:
    testMode: EditMode
    projectPath: .
    artifactsPath: ./test-results
    githubToken: ${{ secrets.GITHUB_TOKEN }}

- name: Run Play Mode Tests
  uses: game-ci/unity-test-runner@v4
  with:
    testMode: PlayMode
    projectPath: .
    artifactsPath: ./test-results
    githubToken: ${{ secrets.GITHUB_TOKEN }}
```

## TDD Cycle Summary

1. **Write a failing test** — describe the desired behavior
2. **Run the test** — confirm it fails (RED) for the right reason
3. **Implement** — write the minimum code to pass
4. **Run the test** — confirm it passes (GREEN)
5. **Refactor** — clean up while tests stay green
6. **Commit** — test + implementation together

Never skip running the tests. A test that was never executed proves nothing. An implementation that was never verified is not done.

## Common Pitfalls

| Issue | Solution |
|-------|----------|
| `MissingReferenceException` in teardown | Use `Object.Destroy`, not direct null. Check for destroyed objects with `obj == null` (Unity overloads `==`). |
| Test passes alone, fails in batch | Tests share state — ensure [SetUp]/[TearDown] clean everything. Static fields are dangerous. |
| Physics not working in Play Mode test | Wait for `WaitForFixedUpdate()`, not just `yield return null`. Physics runs in FixedUpdate. |
| `NullReferenceException` in `Awake()`/`Start()` | AddComponent triggers Awake immediately. Set dependencies before AddComponent or use Initialize pattern. |
| Coroutine tests hang | [UnityTest] required for coroutines. Regular [Test] cannot yield. Set reasonable timeouts. |
| Tests slow due to scene loading | Prefer constructing minimal test objects over loading full scenes. Reserve scene tests for integration. |
| Flaky timing tests | Use `yield return new WaitUntil(() => condition)` with a timeout instead of `WaitForSeconds`. |
