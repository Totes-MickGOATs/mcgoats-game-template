# Unity UI Toolkit

UI Toolkit is Unity's modern UI system, replacing IMGUI for editor UI and increasingly used for runtime game UI. It uses a web-inspired model: UXML for structure, USS for styling, and C# for logic.

## When to Use UI Toolkit vs UGUI

| Use Case | Recommended System |
|----------|-------------------|
| Menus, settings, HUD overlays | **UI Toolkit** — cleaner styling, better tooling |
| World-space UI (health bars above enemies) | **UGUI** — native 3D canvas support |
| Complex runtime animations on UI | **UGUI** — more mature DOTween/animation integration |
| Editor custom inspectors and windows | **UI Toolkit** — this is the primary target |
| Data-heavy lists (inventory, leaderboards) | **UI Toolkit** — virtualized ListView |

## UXML — Structure

UXML defines the visual hierarchy declaratively. Think of it as HTML for Unity UI.

```xml
<!-- Assets/UI/MainMenu.uxml -->
<ui:UXML xmlns:ui="UnityEngine.UIElements" xmlns:uie="UnityEditor.UIElements">
    <ui:Template name="SettingsPanel" src="project://database/Assets/UI/SettingsPanel.uxml" />

    <ui:VisualElement name="root" class="main-menu">
        <ui:VisualElement name="header" class="header-bar">
            <ui:Label name="title" text="My Game" class="title-text" />
        </ui:VisualElement>

        <ui:VisualElement name="button-container" class="button-column">
            <ui:Button name="btn-play" text="Play" class="menu-button primary" />
            <ui:Button name="btn-settings" text="Settings" class="menu-button" />
            <ui:Button name="btn-quit" text="Quit" class="menu-button" />
        </ui:VisualElement>

        <!-- Reuse a template -->
        <ui:Instance template="SettingsPanel" name="settings-panel" />
    </ui:VisualElement>
</ui:UXML>
```

### Key Elements

| Element | Purpose |
|---------|---------|
| `VisualElement` | Generic container (like `<div>`) |
| `Label` | Text display |
| `Button` | Clickable button |
| `TextField` | Text input |
| `Toggle` | Checkbox |
| `Slider` / `SliderInt` | Range input |
| `DropdownField` | Dropdown selector |
| `ListView` | Virtualized scrolling list |
| `ScrollView` | Scrollable container |
| `Foldout` | Collapsible section |
| `ProgressBar` | Progress display |
| `RadioButton` / `RadioButtonGroup` | Exclusive selection |
| `Template` / `Instance` | UXML reuse |

### Template Reuse

Define reusable UI fragments as separate UXML files, then instantiate them:

```xml
<!-- ItemRow.uxml -->
<ui:UXML xmlns:ui="UnityEngine.UIElements">
    <ui:VisualElement class="item-row">
        <ui:Label name="item-name" />
        <ui:Label name="item-count" />
    </ui:VisualElement>
</ui:UXML>
```

## USS — Styling

USS (Unity Style Sheets) uses CSS-like syntax with Unity-specific properties.

```css
/* Assets/UI/MainMenu.uss */

/* Type selector — matches all Labels */
Label {
    color: #CCCCCC;
    font-size: 16px;
    -unity-font-style: normal;
}

/* Class selector — matches .menu-button */
.menu-button {
    width: 300px;
    height: 60px;
    margin: 8px 0;
    padding: 12px 24px;
    background-color: rgba(40, 40, 40, 0.9);
    border-width: 2px;
    border-color: #555555;
    border-radius: 8px;
    color: white;
    font-size: 20px;
    -unity-text-align: middle-center;
    transition-duration: 0.15s;
    transition-property: background-color, border-color, scale;
}

/* Name selector — matches #title */
#title {
    font-size: 48px;
    -unity-font-style: bold;
    color: #FFD700;
}

/* Pseudo-states */
.menu-button:hover {
    background-color: rgba(60, 60, 60, 0.95);
    border-color: #888888;
    scale: 1.02 1.02;
}

.menu-button:active {
    background-color: rgba(80, 80, 80, 1.0);
    scale: 0.98 0.98;
}

.menu-button:focus {
    border-color: #4488FF;
    border-width: 3px;
}

.menu-button:disabled {
    opacity: 0.4;
}

/* Combined selectors */
.menu-button.primary {
    background-color: rgba(30, 80, 160, 0.9);
    border-color: #4488FF;
}

.menu-button.primary:hover {
    background-color: rgba(40, 100, 200, 0.95);
}
```

### USS Variables (Theming)

Define variables for consistent theming and runtime theme switching:

```css
/* Theme-Light.uss */
:root {
    --bg-primary: #F0F0F0;
    --bg-secondary: #FFFFFF;
    --text-primary: #222222;
    --text-secondary: #666666;
    --accent: #2266CC;
    --accent-hover: #3388EE;
    --border-default: #CCCCCC;
    --font-size-body: 16px;
    --font-size-heading: 28px;
    --spacing-sm: 4px;
    --spacing-md: 8px;
    --spacing-lg: 16px;
}

/* Consume variables */
.panel {
    background-color: var(--bg-primary);
    padding: var(--spacing-lg);
    border-color: var(--border-default);
}

.heading {
    font-size: var(--font-size-heading);
    color: var(--text-primary);
}
```

### USS Transitions and Animations

```css
.card {
    transition-property: translate, opacity, scale;
    transition-duration: 0.3s, 0.2s, 0.3s;
    transition-timing-function: ease-out-cubic;
    opacity: 1;
    translate: 0 0;
}

.card.hidden {
    opacity: 0;
    translate: 0 20px;
}
```

## Runtime UI — UIDocument and PanelSettings

### UIDocument Component

Attach to a GameObject to display UI Toolkit content at runtime:

- **Source Asset** — the UXML file to render
- **Panel Settings** — shared rendering configuration
- **Sort Order** — higher values render on top (like Canvas sortingOrder)

### PanelSettings Asset

Create via Assets > Create > UI Toolkit > Panel Settings Asset:

- **Theme Style Sheet** — default USS applied to all documents using this panel
- **Scale Mode** — Constant Pixel Size, Scale With Screen Size, Constant Physical Size
- **Reference Resolution** — base resolution for Scale With Screen Size (e.g., 1920x1080)
- **Match** — 0 = match width, 1 = match height, 0.5 = blend (same concept as UGUI CanvasScaler)

Multiple UIDocuments can share one PanelSettings (same render panel) or use separate ones (independent panels).

## C# Binding

```csharp
using UnityEngine;
using UnityEngine.UIElements;

public class MainMenuController : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;

    private Button _playButton;
    private Button _settingsButton;
    private Button _quitButton;
    private VisualElement _settingsPanel;

    private void OnEnable()
    {
        var root = uiDocument.rootVisualElement;

        // Query elements by name
        _playButton = root.Q<Button>("btn-play");
        _settingsButton = root.Q<Button>("btn-settings");
        _quitButton = root.Q<Button>("btn-quit");
        _settingsPanel = root.Q<VisualElement>("settings-panel");

        // Query by class (returns first match)
        var title = root.Q<Label>(className: "title-text");

        // Query all matching elements
        var allButtons = root.Query<Button>(className: "menu-button").ToList();

        // Register callbacks
        _playButton.RegisterCallback<ClickEvent>(OnPlayClicked);
        _settingsButton.RegisterCallback<ClickEvent>(OnSettingsClicked);
        _quitButton.RegisterCallback<ClickEvent>(OnQuitClicked);

        // Hover effects via callbacks (beyond what USS can do)
        _playButton.RegisterCallback<MouseEnterEvent>(evt => PlayHoverSound());

        // Schedule delayed or repeated work
        root.schedule.Execute(() => Debug.Log("After 2 seconds")).StartingIn(2000);
        root.schedule.Execute(() => UpdateClock()).Every(1000);
    }

    private void OnDisable()
    {
        // Always unregister to avoid leaks
        _playButton.UnregisterCallback<ClickEvent>(OnPlayClicked);
        _settingsButton.UnregisterCallback<ClickEvent>(OnSettingsClicked);
        _quitButton.UnregisterCallback<ClickEvent>(OnQuitClicked);
    }

    private void OnPlayClicked(ClickEvent evt) => SceneLoader.LoadGameplay();
    private void OnSettingsClicked(ClickEvent evt)
    {
        _settingsPanel.style.display = _settingsPanel.style.display == DisplayStyle.None
            ? DisplayStyle.Flex
            : DisplayStyle.None;
    }
    private void OnQuitClicked(ClickEvent evt) => Application.Quit();
    private void PlayHoverSound() { /* audio */ }
    private void UpdateClock() { /* update time label */ }
}
```

### Key Callbacks

| Event | When |
|-------|------|
| `ClickEvent` | Click/tap on element |
| `MouseEnterEvent` / `MouseLeaveEvent` | Hover in/out |
| `FocusInEvent` / `FocusOutEvent` | Keyboard/gamepad focus |
| `ChangeEvent<T>` | Value changed (Toggle, Slider, TextField, etc.) |
| `KeyDownEvent` / `KeyUpEvent` | Keyboard input while focused |
| `NavigationMoveEvent` | Gamepad/keyboard navigation |
| `GeometryChangedEvent` | Element resized/repositioned |
| `AttachToPanelEvent` / `DetachFromPanelEvent` | Added/removed from panel |

### Value Change Handling

```csharp
var slider = root.Q<Slider>("volume-slider");
slider.RegisterValueChangedCallback(evt =>
{
    AudioListener.volume = evt.newValue;
    Debug.Log($"Volume: {evt.previousValue} -> {evt.newValue}");
});

var textField = root.Q<TextField>("player-name");
textField.RegisterValueChangedCallback(evt =>
{
    ValidatePlayerName(evt.newValue);
});
```

## ListView — Virtualized Lists

ListView is essential for inventory, leaderboards, or any scrollable list with many items:

```csharp
public class LeaderboardUI : MonoBehaviour
{
    [SerializeField] private UIDocument uiDocument;
    [SerializeField] private VisualTreeAsset rowTemplate;

    private List<LeaderboardEntry> _entries;

    private void OnEnable()
    {
        var listView = uiDocument.rootVisualElement.Q<ListView>("leaderboard-list");

        listView.itemsSource = _entries;
        listView.fixedItemHeight = 50;
        listView.selectionType = SelectionType.Single;

        // How to create each row's visual
        listView.makeItem = () => rowTemplate.Instantiate();

        // How to populate a row with data
        listView.bindItem = (element, index) =>
        {
            var entry = _entries[index];
            element.Q<Label>("rank").text = $"#{index + 1}";
            element.Q<Label>("name").text = entry.PlayerName;
            element.Q<Label>("score").text = entry.Score.ToString("N0");
        };

        listView.selectionChanged += OnEntrySelected;
    }

    private void OnEntrySelected(IEnumerable<object> selection)
    {
        var entry = selection.FirstOrDefault() as LeaderboardEntry;
        if (entry != null) ShowPlayerDetails(entry);
    }
}
```

## Custom Controls

Create reusable custom VisualElements:

```csharp
public class HealthBar : VisualElement
{
    // UxmlFactory enables use in UXML
    public new class UxmlFactory : UxmlFactory<HealthBar, UxmlTraits> { }

    public new class UxmlTraits : VisualElement.UxmlTraits
    {
        private UxmlFloatAttributeDescription _maxHealth = new()
            { name = "max-health", defaultValue = 100f };
        private UxmlColorAttributeDescription _barColor = new()
            { name = "bar-color", defaultValue = Color.green };

        public override void Init(VisualElement ve, IUxmlAttributes bag, CreationContext cc)
        {
            base.Init(ve, bag, cc);
            var bar = (HealthBar)ve;
            bar.MaxHealth = _maxHealth.GetValueFromBag(bag, cc);
            bar._fill.style.backgroundColor = _barColor.GetValueFromBag(bag, cc);
        }
    }

    public float MaxHealth { get; set; } = 100f;

    private float _currentHealth;
    public float CurrentHealth
    {
        get => _currentHealth;
        set
        {
            _currentHealth = Mathf.Clamp(value, 0, MaxHealth);
            float pct = MaxHealth > 0 ? _currentHealth / MaxHealth : 0;
            _fill.style.width = Length.Percent(pct * 100f);
            _fill.style.backgroundColor = Color.Lerp(Color.red, Color.green, pct);
        }
    }

    private VisualElement _fill;

    public HealthBar()
    {
        AddToClassList("health-bar");

        var background = new VisualElement();
        background.AddToClassList("health-bar__background");

        _fill = new VisualElement();
        _fill.AddToClassList("health-bar__fill");

        background.Add(_fill);
        Add(background);
    }
}
```

Use in UXML:
```xml
<HealthBar name="player-health" max-health="100" bar-color="#00FF00" />
```

## Responsive Layout — Flexbox

UI Toolkit uses Flexbox for layout, similar to CSS:

```css
/* Vertical column layout (default) */
.panel {
    flex-direction: column;
    align-items: center;      /* horizontal alignment */
    justify-content: center;  /* vertical alignment */
}

/* Horizontal row layout */
.toolbar {
    flex-direction: row;
    justify-content: space-between;
}

/* Flex grow/shrink */
.sidebar { flex-grow: 0; flex-shrink: 0; width: 250px; }  /* fixed width */
.content { flex-grow: 1; }  /* takes remaining space */

/* Wrapping */
.grid {
    flex-direction: row;
    flex-wrap: wrap;
}
.grid-item {
    width: 25%;  /* 4 columns */
    min-width: 150px;  /* wraps when too narrow */
}

/* Absolute positioning (escape flex) */
.tooltip {
    position: absolute;
    left: 100px;
    top: 50px;
}
```

## Runtime Theme Switching

```csharp
public class ThemeManager : MonoBehaviour
{
    [SerializeField] private PanelSettings panelSettings;
    [SerializeField] private ThemeStyleSheet lightTheme;
    [SerializeField] private ThemeStyleSheet darkTheme;

    public void SetDarkMode(bool dark)
    {
        panelSettings.themeStyleSheet = dark ? darkTheme : lightTheme;
    }
}
```

Alternatively, swap USS variables at runtime:

```csharp
// Override a custom property on the root
var root = uiDocument.rootVisualElement;
root.style.SetCustomProperty("--bg-primary", new StyleColor(Color.black));
```

## Programmatic Animation

```csharp
// Experimental animation API
element.experimental.animation
    .Start(new StyleValues { opacity = 0, top = -50 },
           new StyleValues { opacity = 1, top = 0 },
           300)
    .Ease(Easing.OutCubic)
    .OnCompleted(() => Debug.Log("Animation done"));
```

## UI Toolkit Debugger

Open via **Window > UI Toolkit > Debugger**:

- **Pick Element** — click in Game view to select and inspect any element
- **Style Inspector** — see computed styles, which USS rules apply, overrides
- **Hierarchy** — full visual tree, similar to browser DevTools
- **Layout** — see flex properties, margins, padding, borders visually

This is the most powerful tool for debugging layout issues. Use it before guessing at USS changes.

## Data Binding

For editor tools or runtime data binding:

```csharp
// Runtime binding (manual — most common in games)
public void BindPlayerData(PlayerData data)
{
    var nameLabel = root.Q<Label>("player-name");
    var healthBar = root.Q<HealthBar>("player-health");

    // Update on change — use events or polling
    data.OnHealthChanged += hp => healthBar.CurrentHealth = hp;
    nameLabel.text = data.PlayerName;
}

// SerializedObject binding (editor tools)
public override VisualElement CreateInspectorGUI()
{
    var root = new VisualElement();
    var speedField = new FloatField("Speed");
    speedField.BindProperty(serializedObject.FindProperty("speed"));
    root.Add(speedField);
    return root;
}
```
