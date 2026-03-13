# Unity E2E Testing Automation

Comprehensive guide to automating end-to-end testing in Unity projects.

## Testing Pyramid for Games

| Level | What to Test | Tools | Speed |
|-------|-------------|-------|-------|
| **Unit** | Pure functions, math, data | Unity Test Framework (EditMode) | Fast |
| **Integration** | Component wiring, system interaction | Unity Test Framework (PlayMode) | Medium |
| **E2E** | Full gameplay flows, boot-to-play | PlayMode + InputTestFixture + AltTester | Slow |

**Rule of thumb:** Heavy unit/integration coverage, few but meaningful E2E tests covering critical user journeys.

---

## 1. Unity Test Framework (Built-in Foundation)

### PlayMode Tests for E2E

PlayMode tests run inside a real game loop — the foundation for E2E testing.

```csharp
using System.Collections;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;
using UnityEngine.SceneManagement;

public class Test_GameFlow
{
    [UnityTest]
    public IEnumerator BootToGameplay_LoadsAllScenes()
    {
        // Load boot scene
        SceneManager.LoadScene("Boot", LoadSceneMode.Single);
        yield return new WaitForSeconds(1f);

        // Verify main menu loaded
        yield return new WaitUntil(() =>
            SceneManager.GetActiveScene().name == "MainMenu");

        // Find and click Play button
        var playButton = GameObject.Find("PlayButton");
        Assert.IsNotNull(playButton, "Play button not found in MainMenu");

        // Simulate click (see Input Simulation section)
        playButton.GetComponent<UnityEngine.UI.Button>().onClick.Invoke();

        // Wait for gameplay scene
        yield return new WaitUntil(() =>
            SceneManager.GetActiveScene().name == "Gameplay");

        // Verify critical systems exist
        Assert.IsNotNull(GameObject.FindFirstObjectByType<Camera>());
        yield return null;
    }

    [UnityTest]
    public IEnumerator PhysicsSettles_WithinTimeout()
    {
        // Load test scene
        SceneManager.LoadScene("TestScene");
        yield return new WaitForSeconds(0.5f);

        var rb = GameObject.Find("Player").GetComponent<Rigidbody>();

        // Wait for physics to settle (not a fixed delay)
        float timeout = 5f;
        float elapsed = 0f;
        while (rb.linearVelocity.magnitude > 0.01f && elapsed < timeout)
        {
            yield return new WaitForFixedUpdate();
            elapsed += Time.fixedDeltaTime;
        }

        Assert.Less(rb.linearVelocity.magnitude, 0.01f, "Physics did not settle");
    }
}
```

### Key Attributes

| Attribute | Use |
|-----------|-----|
| `[UnityTest]` | Coroutine test (multi-frame, physics, scene loading) |
| `[Test]` | Synchronous test (single-frame, pure logic) |
| `[UnitySetUp]` / `[UnityTearDown]` | Async setup/teardown (coroutine) |
| `[SetUp]` / `[TearDown]` | Sync setup/teardown |
| `[OneTimeSetUp]` | Once per test class |
| `[Category("E2E")]` | Tag for filtering in CI |
| `[Timeout(30000)]` | Fail if test exceeds 30 seconds |

### Scenes in Tests

- Scenes **must** be in Build Settings to be loadable
- Tests start in a blank scene — always load explicitly
- Clean up instantiated objects in `[TearDown]` or load an empty scene

### Test Framework 2.0 (Experimental)

Unity Test Framework 2.0 (`2.0.1-exp.2`) adds async/await support but has been experimental since 2022 with no stable release. **Use 1.4.x/1.5.x stable for production.**

---

## 2. Input Simulation

### InputTestFixture (Built-in, Recommended)

The Input System package provides `InputTestFixture` for programmatic input:

```csharp
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

public class Test_PlayerMovement : InputTestFixture
{
    private Keyboard _keyboard;
    private Gamepad _gamepad;

    public override void Setup()
    {
        base.Setup(); // Creates isolated input state
        _keyboard = InputSystem.AddDevice<Keyboard>();
        _gamepad = InputSystem.AddDevice<Gamepad>();
    }

    [UnityTest]
    public IEnumerator Player_MovesForward_OnWKey()
    {
        SceneManager.LoadScene("TestScene");
        yield return new WaitForSeconds(0.5f);

        var player = GameObject.Find("Player");
        var startPos = player.transform.position;

        // Simulate W key press
        Press(_keyboard.wKey);
        yield return new WaitForSeconds(1f);
        Release(_keyboard.wKey);

        Assert.Greater(player.transform.position.z, startPos.z);
    }

    [UnityTest]
    public IEnumerator Player_Steers_WithGamepadStick()
    {
        SceneManager.LoadScene("TestScene");
        yield return new WaitForSeconds(0.5f);

        // Set left stick to full right
        Set(_gamepad.leftStick, new Vector2(1f, 0f));
        yield return new WaitForSeconds(0.5f);

        // Verify steering response
        var player = GameObject.Find("Player");
        Assert.Greater(player.transform.rotation.eulerAngles.y, 0f);
    }
}
```

### Input Recording & Replay

```csharp
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

// Record input events
var trace = new InputEventTrace();
trace.Enable();
// ... player plays the game ...
trace.Disable();
trace.WriteTo("test-recording.inputtrace");

// Replay in a test
var trace = InputEventTrace.LoadFrom("test-recording.inputtrace");
var replay = trace.Replay()
    .WithAllDevicesMappedToNewInstances()
    .PlayAllEventsAccordingToTimestamps();
```

### Touch Simulation

- `TouchSimulation.Enable()` mirrors mouse/pen to virtual touchscreen
- Unity Device Simulator: single touch only (no multitouch)
- For multitouch: use AltTester or Airtest/Poco

**Gotcha:** Custom `[InitializeOnLoad]` input registrations are NOT loaded in test isolation. Re-register layouts manually in `Setup()`.

---

## 3. Visual / Screenshot Testing

### Graphics Test Framework

Package: `com.unity.testframework.graphics`

```csharp
using UnityEngine.TestTools.Graphics;

[UnityTest]
public IEnumerator Scene_RendersCorrectly()
{
    SceneManager.LoadScene("TestScene");
    yield return new WaitForSeconds(1f);

    var camera = GameObject.FindFirstObjectByType<Camera>();

    // Load reference image (stored in Assets/ReferenceImages/)
    var referenceImage = Resources.Load<Texture2D>("ReferenceImages/TestScene_ref");

    // Compare rendered output to reference
    ImageAssert.AreEqual(referenceImage, camera, new ImageComparisonSettings
    {
        TargetWidth = 1920,
        TargetHeight = 1080,
        PerPixelCorrectnessThreshold = 0.005f
    });
}
```

Reference images organized by: `ColorSpace/Platform/GraphicsAPI`. Generate initial references by running tests once.

### DIY Screenshot Comparison

```csharp
[UnityTest]
public IEnumerator UI_LooksCorrect()
{
    SceneManager.LoadScene("MainMenu");
    yield return new WaitForSeconds(1f);
    yield return new WaitForEndOfFrame();

    var screenshot = ScreenCapture.CaptureScreenshotAsTexture();
    var reference = Resources.Load<Texture2D>("References/MainMenu");

    float diff = CompareTextures(screenshot, reference);
    Assert.Less(diff, 0.02f, "Visual regression detected");
}

private float CompareTextures(Texture2D a, Texture2D b)
{
    var pixelsA = a.GetPixels();
    var pixelsB = b.GetPixels();
    float totalDiff = 0f;
    for (int i = 0; i < pixelsA.Length; i++)
    {
        totalDiff += Mathf.Abs(pixelsA[i].r - pixelsB[i].r);
        totalDiff += Mathf.Abs(pixelsA[i].g - pixelsB[i].g);
        totalDiff += Mathf.Abs(pixelsA[i].b - pixelsB[i].b);
    }
    return totalDiff / (pixelsA.Length * 3f);
}
```

**Cannot run with `-nographics`.** Requires GPU in CI (Linux: Xvfb or real GPU).

---

## 4. Third-Party E2E Tools

### Comparison Matrix

| Tool | Cost | Languages | True E2E | CI-Ready | Setup |
|------|------|-----------|----------|----------|-------|
| **AltTester** | Free (LGPL) | C#, Python, Java | Yes | Yes | Medium |
| **GameDriver** | Free solo, $150+/mo | C# | Yes | Yes | Medium |
| **Airtest/Poco** | Free (OSS) | Python | Yes | Yes | Medium |
| **Regression Games** | Free tier | C# | Yes | Yes | Low-Medium |
| **modl:test** | Commercial | No code | Yes (AI) | Yes | Low |

### AltTester (Recommended Open-Source)

Instruments Unity builds to expose game object hierarchy for external test scripts.

```csharp
// C# test using AltTester SDK
[Test]
public void GameFlow_StartToFinish()
{
    var altDriver = new AltDriver();

    // Find and tap Play button
    altDriver.FindObject(By.NAME, "PlayButton").Tap();

    // Wait for gameplay scene
    altDriver.WaitForCurrentSceneToBe("Gameplay", timeout: 10);

    // Verify player exists
    var player = altDriver.FindObject(By.NAME, "Player");
    Assert.IsNotNull(player);

    // Simulate input
    altDriver.KeyDown(AltKeyCode.W);
    Thread.Sleep(2000);
    altDriver.KeyUp(AltKeyCode.W);

    // Verify movement
    var newPos = altDriver.FindObject(By.NAME, "Player").GetWorldPosition();
    Assert.Greater(newPos.z, 0);

    altDriver.Stop();
}
```

**Setup:** Add AltTester SDK to Unity project → Instrument build → Run AltTester Server → Connect tests.

Works on: PC, Mac, Android, iOS, WebGL. Supports both Input Manager and Input System. Latest: v2.3.0 (active development, Feb 2026).

### Regression Games (AI-Powered)

```csharp
// Bot that automatically explores your game
[RGBot]
public class ExplorerBot : MonoBehaviour
{
    void Update()
    {
        // AI-driven exploration + screenshot capture
        RGBotManager.Instance.NavigateRandomly();
        RGBotManager.Instance.CaptureState();
    }
}
```

Features: Smart Recording, OCR, bot sequences, LLM-powered agent builder. Free tier available.

---

## 5. Performance Testing

### Unity Performance Testing Extension

Package: `com.unity.test-framework.performance` (stable: 3.2.0)

```csharp
using Unity.PerformanceTesting;

[Test, Performance]
public void PhysicsStep_Under2ms()
{
    Measure.Method(() =>
    {
        Physics.Simulate(Time.fixedDeltaTime);
    })
    .WarmupCount(5)
    .MeasurementCount(50)
    .Run();
}

[UnityTest, Performance]
public IEnumerator FrameTime_Under16ms()
{
    SceneManager.LoadScene("Gameplay");
    yield return new WaitForSeconds(2f); // Let scene settle

    yield return Measure.Frames()
        .WarmupCount(10)
        .MeasurementCount(100)
        .Run();
}

[Test, Performance]
public void SpawnSystem_NoGCAllocation()
{
    var pool = new ObjectPool();
    Measure.Method(() =>
    {
        pool.Get();
        pool.Release();
    })
    .GC()
    .MeasurementCount(100)
    .Run();
}
```

### Memory Leak Detection

```csharp
[UnityTest]
public IEnumerator NoMemoryLeaks_AfterSceneReload()
{
    SceneManager.LoadScene("Gameplay");
    yield return new WaitForSeconds(1f);

    long memBefore = Profiler.GetTotalAllocatedMemoryLong();

    // Reload scene 5 times
    for (int i = 0; i < 5; i++)
    {
        SceneManager.LoadScene("Gameplay");
        yield return new WaitForSeconds(1f);
    }

    long memAfter = Profiler.GetTotalAllocatedMemoryLong();
    long growth = memAfter - memBefore;

    // Allow some tolerance (1MB) for legitimate caching
    Assert.Less(growth, 1_000_000, $"Memory grew by {growth} bytes after 5 reloads");
}
```

---

## 6. CI/CD Integration

### GameCI (GitHub Actions — Recommended)

```yaml
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/cache@v3
        with:
          path: Library
          key: Library-${{ hashFiles('Assets/**', 'Packages/**', 'ProjectSettings/**') }}

      - uses: game-ci/unity-test-runner@v4
        env:
          UNITY_LICENSE: ${{ secrets.UNITY_LICENSE }}
        with:
          testMode: PlayMode
          # Filter to only E2E tests
          customParameters: -testCategory E2E
          artifactsPath: test-results

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: test-results
```

### CLI Batch Mode

```bash
# EditMode tests (fast, no scene)
Unity -batchmode -nographics -runTests -testPlatform EditMode \
  -projectPath . -testResults test-results/editmode.xml

# PlayMode tests (needs GPU for rendering tests)
Unity -batchmode -runTests -testPlatform PlayMode \
  -projectPath . -testResults test-results/playmode.xml

# Filter by category
Unity -batchmode -runTests -testPlatform PlayMode \
  -testCategory "E2E" -projectPath . -testResults test-results/e2e.xml
```

### Headless Limitations

- `-nographics`: No GPU, rendering outputs blank. Physics/logic work fine.
- `-batchmode` without `-nographics`: Needs GPU. Linux CI: use Xvfb.
- Screenshot/visual tests need a real GPU or virtual framebuffer.

---

## 7. MCP-Based Testing (Development Time)

For interactive testing during development using Claude Code:

```
Workflow:
1. read_console → check for compilation errors
2. execute_script → set up test conditions
3. play_game → enter play mode
4. execute_script → runtime assertions
5. capture_scene_object / capture_ui_canvas → visual check
6. get_unity_logs → error detection
7. stop_game → end session
```

**Best for:** Interactive development-time verification. **Not for CI.**

---

## 8. Best Practices

### Deterministic Testing

```csharp
[UnitySetUp]
public IEnumerator SetupDeterministic()
{
    // Fixed random seed
    Random.InitState(42);

    // Fixed frame rate
    Application.targetFrameRate = 60;
    QualitySettings.vSyncCount = 0;

    // Fixed physics timestep
    Time.fixedDeltaTime = 1f / 60f;

    yield return null;
}
```

### Flaky Test Mitigation

| Cause | Fix |
|-------|-----|
| **Timing** | `WaitUntil(condition)` with timeout, never bare `WaitForSeconds` |
| **Physics** | Wait for velocity < threshold, not fixed delay |
| **Async ops** | `yield return` the operation, check completion flag |
| **Shared state** | Reset singletons in `[TearDown]`, use `InputTestFixture` |
| **Scene leaks** | Destroy objects in `[TearDown]`, load empty scene between tests |
| **Render diff** | Perceptual diff with threshold, pin GPU/driver in CI |

### Test Scene Design

- Create **minimal test scenes** with only needed systems
- Avoid full production scenes (slow, brittle, hard to maintain)
- Use prefab-based setup: instantiate only what the test needs
- Scene validation tests: verify required components exist

### What NOT to E2E Test

- Pure math (unit test instead)
- Individual component behavior (integration test instead)
- Platform-specific rendering (visual test with per-platform baselines)
- Network latency tolerance (mock the network layer)

---

## Tools to Avoid

| Tool | Reason |
|------|--------|
| `com.unity.automated-testing` | Development halted since Dec 2021, stuck at `0.8.1-preview.2` |
| `BinaryFormatter` for test data | Security vulnerability, deprecated |
| Pixel-exact screenshot comparison | Too brittle across GPUs, use perceptual diff |
| `Thread.Sleep` in tests | Use `WaitForSeconds` / `WaitUntil` instead |
