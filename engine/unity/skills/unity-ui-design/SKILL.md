# Unity UI/UX Design Patterns

Practical patterns for building game UI: menu flows, HUD, settings, gamepad support, localization, and accessibility.

## Menu Flow Architecture

A typical game menu flow:

```
Boot → Splash → MainMenu → Settings
                         → GameMode → LobbySetup → Loading → Gameplay → Pause → Results
                         → Credits
```

### State Machine Approach

Each menu screen is a self-contained prefab/scene. A MenuManager controls transitions:

```csharp
public class MenuManager : MonoBehaviour
{
    [SerializeField] private GameObject mainMenuScreen;
    [SerializeField] private GameObject settingsScreen;
    [SerializeField] private GameObject gameModeScreen;
    [SerializeField] private GameObject loadingScreen;

    private Stack<GameObject> _screenStack = new();
    private GameObject _currentScreen;

    public void ShowScreen(GameObject screen)
    {
        if (_currentScreen != null)
        {
            _screenStack.Push(_currentScreen);
            _currentScreen.SetActive(false);
        }

        _currentScreen = screen;
        _currentScreen.SetActive(true);

        // Auto-select first button for gamepad
        var firstButton = screen.GetComponentInChildren<Selectable>();
        if (firstButton != null)
            EventSystem.current.SetSelectedGameObject(firstButton.gameObject);
    }

    public void GoBack()
    {
        if (_screenStack.Count == 0) return;

        _currentScreen.SetActive(false);
        _currentScreen = _screenStack.Pop();
        _currentScreen.SetActive(true);

        var firstButton = _currentScreen.GetComponentInChildren<Selectable>();
        if (firstButton != null)
            EventSystem.current.SetSelectedGameObject(firstButton.gameObject);
    }
}
```

## Canvas Strategies

### Screen Space — Overlay (HUD)

- Renders on top of everything, no camera reference needed
- Best for: health bars, ammo counters, minimaps, crosshairs
- Sort Order controls layering between multiple canvases
- Always renders at screen resolution

### Screen Space — Camera

- Rendered by a specific camera at a set plane distance
- Best for: UI that needs to interact with post-processing or depth
- Objects can appear between the UI and the world
- Useful for particle effects that appear above gameplay but below HUD

### World Space

- Canvas exists in 3D space like any other GameObject
- Best for: in-world health bars, nameplates, floating damage numbers, diegetic UI (in-game screens)
- Requires a camera reference for raycasting (Event Camera)
- Scale the canvas down (e.g., 0.01) so 1 UI unit = 1cm in world space

```csharp
// World-space health bar that faces the camera
public class WorldSpaceHealthBar : MonoBehaviour
{
    [SerializeField] private Canvas canvas;
    [SerializeField] private Image fillImage;
    private Camera _mainCam;

    private void Start()
    {
        _mainCam = Camera.main;
        canvas.worldCamera = _mainCam;
    }

    private void LateUpdate()
    {
        // Billboard: face camera
        transform.rotation = Quaternion.LookRotation(
            transform.position - _mainCam.transform.position);
    }

    public void SetHealth(float normalized)
    {
        fillImage.fillAmount = normalized;
        fillImage.color = Color.Lerp(Color.red, Color.green, normalized);
    }
}
```

## UGUI Layout System

### RectTransform Anchors and Pivots

Anchors define how an element stretches relative to its parent:

| Anchor Preset | Behavior |
|---------------|----------|
| Center | Fixed size, centered — for popups |
| Stretch-Stretch | Fill parent — for backgrounds |
| Top-Left | Fixed, pinned to corner — for score display |
| Bottom-Stretch | Fixed height, stretch width — for toolbars |

**Pivot** controls the element's origin point (0,0 = bottom-left, 1,1 = top-right, 0.5,0.5 = center). This affects rotation, scaling, and position interpretation.

### Layout Groups

```
HorizontalLayoutGroup — children arranged left-to-right
VerticalLayoutGroup   — children arranged top-to-bottom
GridLayoutGroup       — children in a grid with fixed cell size
```

Key properties:
- **Padding** — inner margins (left, right, top, bottom)
- **Spacing** — gap between children
- **Child Alignment** — where children align when they don't fill the group
- **Child Force Expand** — whether children stretch to fill available space
- **Child Controls Size** — let layout group control child width/height

### Content Size Fitter

Makes an element resize to fit its content:

| Mode | Behavior |
|------|----------|
| Unconstrained | Don't resize |
| Min Size | Size to minimum content |
| Preferred Size | Size to preferred content (text wrapping, child preferred sizes) |

Common combo: VerticalLayoutGroup + ContentSizeFitter(PreferredSize) for auto-sizing lists.

### Aspect Ratio Fitter

Maintains a width/height ratio:

| Mode | Behavior |
|------|----------|
| Width Controls Height | Set width, height auto-calculates |
| Height Controls Width | Set height, width auto-calculates |
| Fit In Parent | Largest size that fits in parent |
| Envelope Parent | Smallest size that covers parent |

## Gamepad-Friendly UI

### Navigation Setup

Every Selectable (Button, Slider, Toggle, etc.) has a Navigation property:

| Mode | Behavior |
|------|----------|
| Automatic | Unity guesses connections (often wrong) |
| Explicit | You manually assign Up/Down/Left/Right targets |
| Horizontal/Vertical | Only navigate in one direction |
| None | Skip this element during navigation |

**Always use Explicit navigation** for important menus. Automatic breaks with complex layouts.

```csharp
// Set up explicit navigation in code
var playBtn = playButton.GetComponent<Button>();
var settingsBtn = settingsButton.GetComponent<Button>();
var quitBtn = quitButton.GetComponent<Button>();

var playNav = playBtn.navigation;
playNav.mode = Navigation.Mode.Explicit;
playNav.selectOnDown = settingsBtn;
playBtn.navigation = playNav;

var settingsNav = settingsBtn.navigation;
settingsNav.mode = Navigation.Mode.Explicit;
settingsNav.selectOnUp = playBtn;
settingsNav.selectOnDown = quitBtn;
settingsBtn.navigation = settingsNav;
```

### Auto-Select First Button

When a menu opens, immediately select the first interactive element so gamepad input works:

```csharp
private void OnEnable()
{
    // Delay one frame — EventSystem needs the objects active first
    StartCoroutine(SelectFirstButton());
}

private IEnumerator SelectFirstButton()
{
    yield return null; // wait one frame
    EventSystem.current.SetSelectedGameObject(firstButton.gameObject);
}
```

### Submit and Cancel Actions

Map gamepad A/B (or Cross/Circle) to Submit and Cancel in Input System:

```csharp
// In a menu screen
private void Update()
{
    if (Input.GetButtonDown("Cancel")) // B button / Escape
    {
        menuManager.GoBack();
    }
}
```

With Input System package:
```csharp
// InputSystem UI module handles Submit/Cancel automatically via InputSystemUIInputModule
// Just ensure your Input Actions have "Submit" and "Cancel" actions in the UI action map
```

## Settings Menu Patterns

### Graphics Settings

```csharp
public class GraphicsSettings : MonoBehaviour
{
    [SerializeField] private TMP_Dropdown qualityDropdown;
    [SerializeField] private TMP_Dropdown resolutionDropdown;
    [SerializeField] private Toggle fullscreenToggle;
    [SerializeField] private Toggle vsyncToggle;

    private Resolution[] _resolutions;

    private void Start()
    {
        // Quality levels
        qualityDropdown.ClearOptions();
        qualityDropdown.AddOptions(QualitySettings.names.ToList());
        qualityDropdown.value = QualitySettings.GetQualityLevel();
        qualityDropdown.onValueChanged.AddListener(QualitySettings.SetQualityLevel);

        // Resolutions — filter duplicates
        _resolutions = Screen.resolutions
            .GroupBy(r => new { r.width, r.height })
            .Select(g => g.Last())
            .ToArray();

        resolutionDropdown.ClearOptions();
        resolutionDropdown.AddOptions(
            _resolutions.Select(r => $"{r.width} x {r.height}").ToList());

        int currentIndex = Array.FindIndex(_resolutions,
            r => r.width == Screen.currentResolution.width
              && r.height == Screen.currentResolution.height);
        resolutionDropdown.value = Mathf.Max(0, currentIndex);
        resolutionDropdown.onValueChanged.AddListener(SetResolution);

        // Fullscreen
        fullscreenToggle.isOn = Screen.fullScreen;
        fullscreenToggle.onValueChanged.AddListener(v =>
            Screen.fullScreenMode = v ? FullScreenMode.FullScreenWindow
                                      : FullScreenMode.Windowed);

        // VSync
        vsyncToggle.isOn = QualitySettings.vSyncCount > 0;
        vsyncToggle.onValueChanged.AddListener(v =>
            QualitySettings.vSyncCount = v ? 1 : 0);
    }

    private void SetResolution(int index)
    {
        var res = _resolutions[index];
        Screen.SetResolution(res.width, res.height, Screen.fullScreenMode);
    }
}
```

### Audio Settings

```csharp
public class AudioSettings : MonoBehaviour
{
    [SerializeField] private Slider masterSlider;
    [SerializeField] private Slider musicSlider;
    [SerializeField] private Slider sfxSlider;

    [SerializeField] private AudioMixer mixer;

    private void Start()
    {
        masterSlider.value = PlayerPrefs.GetFloat("MasterVolume", 0.8f);
        musicSlider.value = PlayerPrefs.GetFloat("MusicVolume", 0.8f);
        sfxSlider.value = PlayerPrefs.GetFloat("SFXVolume", 0.8f);

        masterSlider.onValueChanged.AddListener(v => SetVolume("MasterVolume", v));
        musicSlider.onValueChanged.AddListener(v => SetVolume("MusicVolume", v));
        sfxSlider.onValueChanged.AddListener(v => SetVolume("SFXVolume", v));
    }

    private void SetVolume(string parameter, float linear)
    {
        // Convert linear 0-1 to decibels (-80 to 0)
        float db = linear > 0.001f ? Mathf.Log10(linear) * 20f : -80f;
        mixer.SetFloat(parameter, db);
        PlayerPrefs.SetFloat(parameter, linear);
    }
}
```

## HUD Elements

### Health Bar

```csharp
public class HealthBarUI : MonoBehaviour
{
    [SerializeField] private Image fillImage;
    [SerializeField] private Image backgroundImage;
    [SerializeField] private Gradient colorGradient;

    private float _targetFill;
    private float _currentFill;
    private const float LerpSpeed = 5f;

    public void SetHealth(float current, float max)
    {
        _targetFill = Mathf.Clamp01(current / max);
    }

    private void Update()
    {
        _currentFill = Mathf.Lerp(_currentFill, _targetFill, Time.deltaTime * LerpSpeed);
        fillImage.fillAmount = _currentFill;
        fillImage.color = colorGradient.Evaluate(_currentFill);
    }
}
```

### Floating Damage Numbers

```csharp
public class DamagePopup : MonoBehaviour
{
    [SerializeField] private TMP_Text text;
    [SerializeField] private float floatSpeed = 1f;
    [SerializeField] private float fadeSpeed = 2f;
    [SerializeField] private float lifetime = 1f;

    public void Init(int damage, Color color)
    {
        text.text = damage.ToString();
        text.color = color;
        Destroy(gameObject, lifetime);
    }

    private void Update()
    {
        transform.Translate(Vector3.up * floatSpeed * Time.deltaTime);
        var c = text.color;
        c.a -= fadeSpeed * Time.deltaTime;
        text.color = c;
    }
}
```

## Loading Screen

```csharp
public class LoadingScreen : MonoBehaviour
{
    [SerializeField] private Slider progressBar;
    [SerializeField] private TMP_Text tipText;
    [SerializeField] private string[] tips;

    public IEnumerator LoadSceneAsync(string sceneName)
    {
        gameObject.SetActive(true);
        tipText.text = tips[Random.Range(0, tips.Length)];

        var op = SceneManager.LoadSceneAsync(sceneName);
        op.allowSceneActivation = false;

        while (op.progress < 0.9f)
        {
            // progress goes 0..0.9 while loading, then waits for allowSceneActivation
            progressBar.value = Mathf.Clamp01(op.progress / 0.9f);
            yield return null;
        }

        progressBar.value = 1f;
        yield return new WaitForSeconds(0.5f); // brief pause at 100%
        op.allowSceneActivation = true;
    }
}
```

## Popup / Modal System

Stack-based modal management that blocks input to underlying layers:

```csharp
public class ModalManager : MonoBehaviour
{
    public static ModalManager Instance { get; private set; }

    [SerializeField] private GameObject dimOverlay; // semi-transparent black
    private Stack<GameObject> _modalStack = new();

    private void Awake() => Instance = this;

    public void ShowModal(GameObject modalPrefab)
    {
        var modal = Instantiate(modalPrefab, transform);
        _modalStack.Push(modal);
        dimOverlay.SetActive(true);
        dimOverlay.transform.SetSiblingIndex(modal.transform.GetSiblingIndex() - 1);

        // Select first button in modal
        var firstButton = modal.GetComponentInChildren<Selectable>();
        if (firstButton != null)
            EventSystem.current.SetSelectedGameObject(firstButton.gameObject);
    }

    public void CloseTopModal()
    {
        if (_modalStack.Count == 0) return;

        var modal = _modalStack.Pop();
        Destroy(modal);

        if (_modalStack.Count == 0)
            dimOverlay.SetActive(false);
        else
            dimOverlay.transform.SetSiblingIndex(
                _modalStack.Peek().transform.GetSiblingIndex() - 1);
    }
}
```

## Localization

Using Unity's Localization package (`com.unity.localization`):

```csharp
using UnityEngine.Localization;
using UnityEngine.Localization.Settings;

public class LocalizedUI : MonoBehaviour
{
    // Drag a LocalizedString asset in the inspector
    [SerializeField] private LocalizedString localizedTitle;
    [SerializeField] private TMP_Text titleText;

    private void OnEnable()
    {
        localizedTitle.StringChanged += UpdateTitle;
    }

    private void OnDisable()
    {
        localizedTitle.StringChanged -= UpdateTitle;
    }

    private void UpdateTitle(string value) => titleText.text = value;

    // Switch locale at runtime
    public void SetLocale(string code)
    {
        var locale = LocalizationSettings.AvailableLocales.Locales
            .Find(l => l.Identifier.Code == code);
        if (locale != null)
            LocalizationSettings.SelectedLocale = locale;
    }
}
```

### Smart Strings

```
"You have {playerCoins} coins"       → "You have 42 coins"
"{itemCount:plural:item|items}"       → "3 items"
"{score:N0}"                          → "1,234"
```

## Accessibility

### Colorblind Modes

```csharp
public class AccessibilityManager : MonoBehaviour
{
    [SerializeField] private Material colorblindMaterial; // post-processing shader
    [SerializeField] private Volume postProcessVolume;

    public enum ColorblindMode { None, Protanopia, Deuteranopia, Tritanopia }

    public void SetColorblindMode(ColorblindMode mode)
    {
        // Apply color correction matrix via post-process or global shader
        colorblindMaterial.SetInt("_Mode", (int)mode);
        PlayerPrefs.SetInt("ColorblindMode", (int)mode);
    }
}
```

### Text Scaling

```csharp
public void SetTextScale(float scale) // 0.75 to 1.5
{
    // Scale the Canvas reference resolution inversely
    // Smaller reference = larger UI elements
    var scaler = canvas.GetComponent<CanvasScaler>();
    scaler.referenceResolution = new Vector2(1920f / scale, 1080f / scale);
    PlayerPrefs.SetFloat("TextScale", scale);
}
```

### Subtitle Options

Provide: enable/disable subtitles, subtitle text size, background opacity, speaker color coding.

## Screen Resolution and CanvasScaler

```csharp
// CanvasScaler setup for responsive UI
var scaler = canvas.GetComponent<CanvasScaler>();
scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
scaler.referenceResolution = new Vector2(1920, 1080);
scaler.matchWidthOrHeight = 0.5f; // blend between width and height matching

// matchWidthOrHeight:
// 0   = scale based on width  (good for landscape-only games)
// 1   = scale based on height (good for portrait-only games)
// 0.5 = blend (good general default)
```

### Safe Areas (Notch Handling)

```csharp
public class SafeAreaHandler : MonoBehaviour
{
    private RectTransform _panel;

    private void Awake()
    {
        _panel = GetComponent<RectTransform>();
        ApplySafeArea();
    }

    private void ApplySafeArea()
    {
        var safeArea = Screen.safeArea;
        var anchorMin = safeArea.position;
        var anchorMax = safeArea.position + safeArea.size;

        anchorMin.x /= Screen.width;
        anchorMin.y /= Screen.height;
        anchorMax.x /= Screen.width;
        anchorMax.y /= Screen.height;

        _panel.anchorMin = anchorMin;
        _panel.anchorMax = anchorMax;
    }
}
```
