# Unity Scene Management

> Patterns for loading, unloading, and organizing scenes -- from simple single-scene to multi-scene additive architectures.

## Scene Loading Basics

### Synchronous Loading

```csharp
using UnityEngine.SceneManagement;

// Load by name (must be in Build Settings)
SceneManager.LoadScene("Gameplay");

// Load by build index
SceneManager.LoadScene(1);

// Load modes
SceneManager.LoadScene("Gameplay", LoadSceneMode.Single);    // Unloads current scene first (default)
SceneManager.LoadScene("UI_HUD", LoadSceneMode.Additive);    // Keeps current scene, adds new one
```

**Problems with synchronous loading:**
- Freezes the game until the scene is fully loaded
- No loading screen possible
- Causes visible frame hitches

Use synchronous loading only for tiny scenes or initial boot.

### Asynchronous Loading

```csharp
public class SceneLoader : MonoBehaviour
{
    public async void LoadScene(string sceneName)
    {
        AsyncOperation asyncLoad = SceneManager.LoadSceneAsync(sceneName);

        // Optional: prevent the scene from activating immediately
        asyncLoad.allowSceneActivation = false;

        while (!asyncLoad.isDone)
        {
            // Progress goes from 0 to 0.9, then jumps to 1.0 on activation
            float progress = Mathf.Clamp01(asyncLoad.progress / 0.9f);
            Debug.Log($"Loading: {progress:P0}");

            // Activate when ready (progress reaches 0.9)
            if (asyncLoad.progress >= 0.9f)
            {
                // Wait for player input, minimum time, or just activate
                asyncLoad.allowSceneActivation = true;
            }

            await System.Threading.Tasks.Task.Yield();
        }
    }
}
```

**Progress quirk:** `asyncLoad.progress` maxes at `0.9f` when `allowSceneActivation = false`. It jumps to `1.0f` only after activation. Normalize with `progress / 0.9f`.

## Loading Screen Pattern

A robust loading screen that handles async loading with minimum display time and fade transitions.

```csharp
public class LoadingScreen : MonoBehaviour
{
    [SerializeField] private CanvasGroup _canvasGroup;
    [SerializeField] private Slider _progressBar;
    [SerializeField] private TMP_Text _progressText;
    [SerializeField] private float _minimumDisplayTime = 1.5f;
    [SerializeField] private float _fadeDuration = 0.3f;

    private static LoadingScreen _instance;

    private void Awake()
    {
        _instance = this;
        _canvasGroup.alpha = 0f;
        _canvasGroup.blocksRaycasts = false;
        gameObject.SetActive(false);
    }

    public static void Load(string sceneName)
    {
        _instance.gameObject.SetActive(true);
        _instance.StartCoroutine(_instance.LoadRoutine(sceneName));
    }

    private IEnumerator LoadRoutine(string sceneName)
    {
        // Fade in loading screen
        yield return FadeCanvas(0f, 1f);
        _canvasGroup.blocksRaycasts = true;

        float startTime = Time.unscaledTime;
        AsyncOperation asyncLoad = SceneManager.LoadSceneAsync(sceneName);
        asyncLoad.allowSceneActivation = false;

        // Update progress bar while loading
        while (asyncLoad.progress < 0.9f)
        {
            float progress = asyncLoad.progress / 0.9f;
            _progressBar.value = progress;
            _progressText.text = $"{progress:P0}";
            yield return null;
        }

        _progressBar.value = 1f;
        _progressText.text = "100%";

        // Enforce minimum display time (prevents flash)
        float elapsed = Time.unscaledTime - startTime;
        if (elapsed < _minimumDisplayTime)
        {
            yield return new WaitForSecondsRealtime(_minimumDisplayTime - elapsed);
        }

        // Activate the loaded scene
        asyncLoad.allowSceneActivation = true;
        yield return asyncLoad; // Wait for activation to complete

        // Fade out loading screen
        _canvasGroup.blocksRaycasts = false;
        yield return FadeCanvas(1f, 0f);
        gameObject.SetActive(false);
    }

    private IEnumerator FadeCanvas(float from, float to)
    {
        float elapsed = 0f;
        while (elapsed < _fadeDuration)
        {
            elapsed += Time.unscaledDeltaTime;
            _canvasGroup.alpha = Mathf.Lerp(from, to, elapsed / _fadeDuration);
            yield return null;
        }
        _canvasGroup.alpha = to;
    }
}
```

**Key decisions:**
- `Time.unscaledTime` / `WaitForSecondsRealtime` -- works even when game is paused (`Time.timeScale = 0`)
- `blocksRaycasts` -- prevents clicking through the loading screen
- Minimum display time -- prevents the loading screen from flashing for fast loads

## Additive Scene Loading

Load multiple scenes simultaneously. Essential for separating concerns: managers, gameplay, UI, audio.

```csharp
public class AdditiveSceneLoader : MonoBehaviour
{
    // Load a scene additively
    public async void LoadAdditive(string sceneName)
    {
        AsyncOperation op = SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
        while (!op.isDone) await System.Threading.Tasks.Task.Yield();

        // Optionally set as active scene (new objects instantiate into active scene)
        Scene loadedScene = SceneManager.GetSceneByName(sceneName);
        SceneManager.SetActiveScene(loadedScene);
    }

    // Unload an additive scene
    public async void UnloadScene(string sceneName)
    {
        Scene scene = SceneManager.GetSceneByName(sceneName);
        if (scene.isLoaded)
        {
            AsyncOperation op = SceneManager.UnloadSceneAsync(scene);
            while (!op.isDone) await System.Threading.Tasks.Task.Yield();
        }
    }
}
```

**Active scene matters:** `Instantiate()` places new objects in the active scene. Lighting (ambient, skybox) comes from the active scene. Always set the active scene explicitly when using additive loading.

## Scene Bootstrapper Pattern

The most robust architecture for multi-scene games. One persistent "boot" scene holds managers; gameplay scenes are loaded additively.

```
Scenes/
  _Boot.unity          -- Persistent managers (always loaded, never unloaded)
  _UI.unity            -- HUD, menus (additive, persistent)
  MainMenu.unity       -- Main menu content (additive, swappable)
  Level_01.unity       -- Gameplay content (additive, swappable)
  Level_02.unity       -- Gameplay content (additive, swappable)
```

```csharp
// Lives in _Boot scene, marked DontDestroyOnLoad
public class GameBootstrapper : MonoBehaviour
{
    [SerializeField] private string _uiSceneName = "_UI";
    [SerializeField] private string _firstSceneName = "MainMenu";

    private string _currentContentScene;

    private static GameBootstrapper _instance;
    public static GameBootstrapper Instance => _instance;

    private void Awake()
    {
        if (_instance != null)
        {
            Destroy(gameObject);
            return;
        }
        _instance = this;
        DontDestroyOnLoad(gameObject);
    }

    private IEnumerator Start()
    {
        // Load persistent UI scene
        yield return SceneManager.LoadSceneAsync(_uiSceneName, LoadSceneMode.Additive);

        // Load initial content scene
        yield return LoadContentScene(_firstSceneName);
    }

    public Coroutine TransitionTo(string sceneName)
    {
        return StartCoroutine(TransitionRoutine(sceneName));
    }

    private IEnumerator TransitionRoutine(string sceneName)
    {
        // Signal UI to show loading/transition
        OnSceneTransitionStarted?.Invoke();

        // Unload current content
        if (!string.IsNullOrEmpty(_currentContentScene))
        {
            yield return SceneManager.UnloadSceneAsync(_currentContentScene);
        }

        // Load new content
        yield return LoadContentScene(sceneName);

        OnSceneTransitionCompleted?.Invoke();
    }

    private IEnumerator LoadContentScene(string sceneName)
    {
        yield return SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
        _currentContentScene = sceneName;

        Scene scene = SceneManager.GetSceneByName(sceneName);
        SceneManager.SetActiveScene(scene);
    }

    public event Action OnSceneTransitionStarted;
    public event Action OnSceneTransitionCompleted;
}

// Usage from anywhere:
// GameBootstrapper.Instance.TransitionTo("Level_02");
```

**Benefits:**
- Managers survive scene transitions (audio, input, settings)
- Each gameplay scene is self-contained
- UI persists across scenes without duplication
- Clean separation of concerns

### Ensuring Boot Scene Runs First

If a developer opens Level_01 directly in the editor, the boot scene has not loaded. Handle this with a bootstrap check.

```csharp
// Attach to an empty GameObject in every gameplay scene
public class BootstrapCheck : MonoBehaviour
{
    #if UNITY_EDITOR
    private void Awake()
    {
        // If boot scene hasn't loaded, load it
        if (GameBootstrapper.Instance == null)
        {
            Debug.Log("Boot scene not loaded. Loading bootstrapper...");
            // Remember which scene we're in
            string currentScene = SceneManager.GetActiveScene().name;
            PlayerPrefs.SetString("_EditorReturnScene", currentScene);

            SceneManager.LoadScene("_Boot");
        }
    }
    #endif
}
```

## DontDestroyOnLoad

Prevents a GameObject from being destroyed when a new scene loads (in Single mode).

```csharp
public class AudioManager : MonoBehaviour
{
    private static AudioManager _instance;

    private void Awake()
    {
        // Singleton guard -- prevents duplicates when returning to a scene
        if (_instance != null)
        {
            Destroy(gameObject);
            return;
        }
        _instance = this;
        DontDestroyOnLoad(gameObject);
    }
}
```

**Pitfalls:**
- Objects in DontDestroyOnLoad cannot reference scene objects (they get destroyed)
- If the scene containing the singleton is loaded again, a duplicate spawns -- the guard above is mandatory
- DontDestroyOnLoad objects live in a special hidden scene (visible in Hierarchy under "DontDestroyOnLoad")
- With additive scene loading + bootstrapper pattern, you often do not need DontDestroyOnLoad at all -- the boot scene itself persists

## Scene References Without Strings

Avoid magic strings for scene names. They break silently when scenes are renamed.

### ScriptableObject Scene Reference

```csharp
[CreateAssetMenu(menuName = "Scene Management/Scene Reference")]
public class SceneReference : ScriptableObject
{
    #if UNITY_EDITOR
    [SerializeField] private UnityEditor.SceneAsset _sceneAsset;

    private void OnValidate()
    {
        if (_sceneAsset != null)
        {
            _sceneName = _sceneAsset.name;
            _scenePath = UnityEditor.AssetDatabase.GetAssetPath(_sceneAsset);
        }
    }
    #endif

    [SerializeField, HideInInspector] private string _sceneName;
    [SerializeField, HideInInspector] private string _scenePath;

    public string SceneName => _sceneName;

    public AsyncOperation LoadAsync(LoadSceneMode mode = LoadSceneMode.Single)
    {
        return SceneManager.LoadSceneAsync(_sceneName, mode);
    }

    public AsyncOperation UnloadAsync()
    {
        return SceneManager.UnloadSceneAsync(_sceneName);
    }
}

// Usage in Inspector: drag a SceneReference asset instead of typing a string
public class LevelSelector : MonoBehaviour
{
    [SerializeField] private SceneReference[] _levels;

    public void LoadLevel(int index) => _levels[index].LoadAsync();
}
```

### Enum-Based Scene Index

```csharp
// Simpler alternative -- maintain an enum matching Build Settings order
public enum GameScene
{
    Boot = 0,
    MainMenu = 1,
    Level01 = 2,
    Level02 = 3,
}

public static class SceneExtensions
{
    public static AsyncOperation LoadAsync(this GameScene scene, LoadSceneMode mode = LoadSceneMode.Single)
    {
        return SceneManager.LoadSceneAsync((int)scene, mode);
    }
}

// Usage
GameScene.Level01.LoadAsync();
```

**Tradeoff:** Enum is simpler but requires manual sync with Build Settings. SO references are safer but more setup.

## Cross-Scene Communication

When systems in different scenes need to communicate without direct references.

### Via ScriptableObject Events (Recommended)

```csharp
// Create a GameEvent asset (see ScriptableObjects skill)
// Both scenes reference the same SO event -- no direct coupling

// In gameplay scene:
_onPlayerDied.Raise();

// In UI scene:
_onPlayerDied.Subscribe(ShowGameOverScreen);
```

### Via Static Events

```csharp
public static class GameEvents
{
    public static event Action<string> OnSceneRequested;

    public static void RequestScene(string name) => OnSceneRequested?.Invoke(name);
}

// Any scene can request a transition:
GameEvents.RequestScene("Level_02");

// Bootstrapper listens:
private void OnEnable() => GameEvents.OnSceneRequested += TransitionTo;
private void OnDisable() => GameEvents.OnSceneRequested -= TransitionTo;
```

## Build Settings Management

Scenes must be in File -> Build Settings to be loaded by name or index.

```csharp
// Check if a scene is in build settings (editor utility)
#if UNITY_EDITOR
public static bool IsSceneInBuild(string sceneName)
{
    foreach (var scene in UnityEditor.EditorBuildSettings.scenes)
    {
        if (scene.enabled && scene.path.Contains(sceneName))
            return true;
    }
    return false;
}
#endif
```

**CI/automation tip:** Validate that all referenced scenes are in Build Settings as part of your build validation step. Missing scenes cause runtime errors with no compile-time warning.

## Scene Lifecycle Events

```csharp
// Subscribe to scene events globally
private void OnEnable()
{
    SceneManager.sceneLoaded += OnSceneLoaded;
    SceneManager.sceneUnloaded += OnSceneUnloaded;
    SceneManager.activeSceneChanged += OnActiveSceneChanged;
}

private void OnDisable()
{
    SceneManager.sceneLoaded -= OnSceneLoaded;
    SceneManager.sceneUnloaded -= OnSceneUnloaded;
    SceneManager.activeSceneChanged -= OnActiveSceneChanged;
}

private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
{
    Debug.Log($"Loaded: {scene.name} (mode: {mode})");
}

private void OnSceneUnloaded(Scene scene)
{
    Debug.Log($"Unloaded: {scene.name}");
}

private void OnActiveSceneChanged(Scene oldScene, Scene newScene)
{
    Debug.Log($"Active scene: {oldScene.name} -> {newScene.name}");
}
```

## Multi-Scene Editing in the Editor

Unity supports having multiple scenes open simultaneously in the editor. This is useful for the bootstrapper pattern.

```
Hierarchy:
  _Boot (loaded)
    GameBootstrapper
    AudioManager
  _UI (loaded, additive)
    Canvas
    EventSystem
  Level_01 (loaded, additive, active)
    Terrain
    Player
    Enemies
```

**Editor workflow:**
1. Open `_Boot` scene
2. Drag `_UI` and `Level_01` into Hierarchy (or File -> Open Scene Additive)
3. Right-click `Level_01` -> Set Active Scene
4. Save All (Ctrl+Shift+S) saves each scene independently

**Gotcha:** Objects dragged between scenes in the editor change scene ownership. This can silently break references. Always verify an object's scene in the Inspector header.

## Scene Loading Architecture Decision Guide

| Game Type | Recommended Pattern |
|-----------|-------------------|
| Simple (1-5 scenes) | `LoadSceneAsync` with Single mode + loading screen |
| Medium (menu + levels) | Bootstrapper + additive loading |
| Large (open world) | Addressables + streaming + additive loading |
| Prototype / game jam | Synchronous loading is fine |

## Common Mistakes

1. **Loading by string without validation** -- scene renames cause silent failures
2. **Not handling async properly** -- scene activates before UI is ready
3. **DontDestroyOnLoad without singleton guard** -- duplicate managers on scene reload
4. **Forgetting to set active scene** -- lighting and Instantiate go to wrong scene
5. **Referencing scene objects from persistent objects** -- references become null after scene unload
6. **Not adding scenes to Build Settings** -- works in editor, fails in build
