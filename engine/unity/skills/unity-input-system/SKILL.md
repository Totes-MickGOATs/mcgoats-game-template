# Unity Input System

Reference guide for Unity's New Input System package. Covers setup, action configuration,
reading input, rebinding, multiplayer, and migration from legacy Input.

## Package Installation and Setup

Install via Package Manager or manifest:

```json
// Packages/manifest.json
"com.unity.inputsystem": "1.8.2"
```

After installation, Unity prompts to switch the active input handling:

- **Edit > Project Settings > Player > Active Input Handling** -- set to **Input System Package (New)** or **Both** during migration
- Restart the editor after changing this setting

The new system is event-driven rather than poll-based. Instead of checking `Input.GetKey()` every frame, you define actions and respond to callbacks.

## Input Actions Asset

The Input Actions asset (`.inputactions`) is the central configuration file. Create via **Assets > Create > Input Actions**.

### Structure

```
Input Actions Asset
  +-- Action Map (e.g., "Player", "UI", "Vehicle")
  |     +-- Action (e.g., "Move", "Fire", "Look")
  |     |     +-- Binding (e.g., "<Gamepad>/leftStick", "<Keyboard>/w")
  |     |     +-- Binding Composite (e.g., 2D Vector: WASD)
  |     +-- Action ...
  +-- Action Map ...
  +-- Control Scheme (e.g., "Keyboard+Mouse", "Gamepad")
```

### Action Maps

Group related actions by context:

| Action Map | Purpose | Example Actions |
|------------|---------|-----------------|
| Player | Gameplay movement/combat | Move, Look, Fire, Jump, Interact |
| UI | Menu navigation | Navigate, Submit, Cancel, ScrollWheel |
| Vehicle | Driving-specific | Throttle, Brake, Steer, Handbrake |

Switch maps at runtime:

```csharp
playerInput.SwitchCurrentActionMap("UI");
// Or directly:
inputActions.Player.Disable();
inputActions.UI.Enable();
```

## Action Types

Each action has a type that determines its behavior:

| Type | When to Use | Example |
|------|------------|---------|
| **Value** | Continuous input, tracks state changes | Movement stick, mouse delta, triggers |
| **Button** | Discrete press/release, has default Press interaction | Fire, Jump, Interact |
| **PassThrough** | Raw input, no conflict resolution between devices | When you need every device's input simultaneously |

**Value** actions perform conflict resolution -- if multiple controls are bound, only the most actuated one drives the action. **PassThrough** skips this and forwards all input.

```csharp
// In the .inputactions editor:
// Move: Type = Value, Control Type = Vector2
// Fire: Type = Button
// AnyDeviceInput: Type = PassThrough
```

## Control Schemes

Define which devices constitute a valid input setup:

```
Keyboard+Mouse:
  - <Keyboard> (required)
  - <Mouse> (required)

Gamepad:
  - <Gamepad> (required)

Touch:
  - <Touchscreen> (required)
```

Automatic switching: when `PlayerInput` is set to **Auto-Switch**, changing to a different device mid-game switches the active scheme and triggers `onControlsChanged`.

```csharp
public class ControlSchemeDisplay : MonoBehaviour
{
    PlayerInput _playerInput;

    void OnEnable()
    {
        _playerInput = GetComponent<PlayerInput>();
        _playerInput.onControlsChanged += OnControlsChanged;
    }

    void OnControlsChanged(PlayerInput input)
    {
        string scheme = input.currentControlScheme;
        // Update UI prompts: "Press A" vs "Press Space"
        Debug.Log($"Switched to: {scheme}");
    }
}
```

## Binding Composites

Combine multiple controls into a single logical value:

### 2D Vector (WASD)

```
Move (Value, Vector2):
  +-- 2D Vector Composite
        Up:    <Keyboard>/w
        Down:  <Keyboard>/s
        Left:  <Keyboard>/a
        Right: <Keyboard>/d
```

Mode options: **Digital** (normalized, 8-direction), **Digital Normalized** (default), **Analog** (raw).

### 1D Axis

```
Zoom (Value, float):
  +-- 1D Axis Composite
        Negative: <Keyboard>/minus
        Positive: <Keyboard>/equals
```

### Button With Modifier

```
Sprint (Button):
  +-- Button With One Modifier
        Modifier: <Keyboard>/leftShift
        Button:   <Keyboard>/w
```

## Reading Input

Three approaches, from simplest to most flexible:

### 1. PlayerInput Component (Inspector-Driven)

Attach `PlayerInput` to a GameObject. Set behavior mode:

| Mode | How It Works |
|------|-------------|
| Send Messages | Calls `OnMove(InputValue)`, `OnFire(InputValue)` on same GameObject |
| Broadcast Messages | Same but searches children too |
| Invoke Unity Events | Drag methods in the Inspector like button onClick |
| Invoke C# Events | Subscribe in code to `onActionTriggered` |

```csharp
// Send Messages mode -- method name = "On" + action name
public class PlayerController : MonoBehaviour
{
    Vector2 _moveInput;

    void OnMove(InputValue value)
    {
        _moveInput = value.Get<Vector2>();
    }

    void OnFire(InputValue value)
    {
        if (value.isPressed) Shoot();
    }
}
```

### 2. Generated C# Class

Enable **Generate C# Class** in the Input Actions asset inspector. This creates a strongly-typed wrapper:

```csharp
public class PlayerController : MonoBehaviour
{
    GameInputActions _input; // Generated class name matches asset name

    void Awake()
    {
        _input = new GameInputActions();
    }

    void OnEnable()
    {
        _input.Player.Enable();
        _input.Player.Fire.performed += OnFire;
        _input.Player.Fire.canceled += OnFireReleased;
    }

    void OnDisable()
    {
        _input.Player.Fire.performed -= OnFire;
        _input.Player.Fire.canceled -= OnFireReleased;
        _input.Player.Disable();
    }

    void Update()
    {
        Vector2 move = _input.Player.Move.ReadValue<Vector2>();
        transform.Translate(new Vector3(move.x, 0, move.y) * Time.deltaTime * 5f);
    }

    void OnFire(InputAction.CallbackContext ctx) { Shoot(); }
    void OnFireReleased(InputAction.CallbackContext ctx) { StopShooting(); }
}
```

### 3. Direct InputAction References

Reference individual actions without the full asset:

```csharp
public class SimpleController : MonoBehaviour
{
    [SerializeField] InputActionReference _moveAction;
    [SerializeField] InputActionReference _fireAction;

    void OnEnable()
    {
        _moveAction.action.Enable();
        _fireAction.action.Enable();
        _fireAction.action.performed += ctx => Shoot();
    }

    void OnDisable()
    {
        _moveAction.action.Disable();
        _fireAction.action.Disable();
    }

    void Update()
    {
        Vector2 move = _moveAction.action.ReadValue<Vector2>();
        // ...
    }
}
```

## Input Action Phases

Every action fires callbacks at specific phases:

| Phase | When | Use For |
|-------|------|---------|
| **Started** | Control actuated above default | Charge-up begins, button touch |
| **Performed** | Interaction completed | Fire bullet, jump, confirm |
| **Canceled** | Control released / interaction failed | Release charge, stop aiming |

```csharp
// Charge attack pattern
_input.Player.HeavyAttack.started += ctx => StartCharging();
_input.Player.HeavyAttack.performed += ctx => ReleaseCharge(); // Hold interaction completed
_input.Player.HeavyAttack.canceled += ctx => CancelCharge();   // Released too early
```

## Interactions

Modify when `performed` fires:

| Interaction | Behavior | Parameters |
|-------------|----------|------------|
| **Press** | On press, release, or both | `pressPoint` |
| **Hold** | Must hold for duration | `duration` (default 0.4s) |
| **Tap** | Press and release within time | `duration` (default 0.2s) |
| **SlowTap** | Press and release after minimum time | `duration` (default 0.5s) |
| **MultiTap** | Multiple taps in succession | `tapCount`, `tapDelay`, `tapTime` |

Set interactions per-action or per-binding in the Input Actions editor.

### Custom Interaction

```csharp
#if UNITY_EDITOR
[UnityEditor.InitializeOnLoad]
#endif
public class DoublePressInteraction : IInputInteraction
{
    public float tapTime = 0.3f;

    static DoublePressInteraction()
    {
        InputSystem.RegisterInteraction<DoublePressInteraction>();
    }

    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    static void Init() { } // Ensure static constructor runs

    public void Process(ref InputInteractionContext context)
    {
        // Custom state machine logic
        // Call context.Started(), context.Performed(), context.Canceled()
    }

    public void Reset() { }
}
```

## Rebinding

Runtime rebinding lets players customize controls:

```csharp
public class RebindUI : MonoBehaviour
{
    [SerializeField] InputActionReference _actionToRebind;
    [SerializeField] int _bindingIndex = 0;
    [SerializeField] TMP_Text _bindingText;
    [SerializeField] GameObject _rebindOverlay;

    InputActionRebindingExtensions.RebindingOperation _rebindOp;

    public void StartRebind()
    {
        _actionToRebind.action.Disable();
        _rebindOverlay.SetActive(true);

        _rebindOp = _actionToRebind.action.PerformInteractiveRebinding(_bindingIndex)
            .WithControlsExcluding("<Mouse>/position")
            .WithControlsExcluding("<Keyboard>/escape")
            .WithCancelingThrough("<Keyboard>/escape")
            .OnMatchWaitForAnother(0.1f)
            .OnComplete(op => RebindComplete())
            .OnCancel(op => RebindCanceled())
            .Start();
    }

    void RebindComplete()
    {
        _rebindOp.Dispose();
        _rebindOverlay.SetActive(false);
        _actionToRebind.action.Enable();
        _bindingText.text = InputControlPath.ToHumanReadableString(
            _actionToRebind.action.bindings[_bindingIndex].effectivePath,
            InputControlPath.HumanReadableStringOptions.OmitDevice);

        // Save: store overrides as JSON
        string overrides = _actionToRebind.action.actionMap.asset.SaveBindingOverridesAsJson();
        PlayerPrefs.SetString("InputOverrides", overrides);
    }

    void RebindCanceled()
    {
        _rebindOp.Dispose();
        _rebindOverlay.SetActive(false);
        _actionToRebind.action.Enable();
    }
}

// Loading saved overrides on startup:
string json = PlayerPrefs.GetString("InputOverrides", string.Empty);
if (!string.IsNullOrEmpty(json))
    inputActions.asset.LoadBindingOverridesFromJson(json);
```

## Multiple Players

`PlayerInputManager` handles player joining for local multiplayer:

```csharp
// Setup in Inspector:
// - PlayerInputManager component on a manager GameObject
// - Join Behavior: Join Players When Button Is Pressed
// - Player Prefab: prefab with PlayerInput component
// - Max Player Count: 4
// - Split Screen: enable if needed

public class MultiplayerManager : MonoBehaviour
{
    void OnEnable()
    {
        PlayerInputManager.instance.onPlayerJoined += OnPlayerJoined;
        PlayerInputManager.instance.onPlayerLeft += OnPlayerLeft;
    }

    void OnPlayerJoined(PlayerInput player)
    {
        Debug.Log($"Player {player.playerIndex} joined with {player.currentControlScheme}");
        // Assign spawn point, team, color, etc.
    }

    void OnPlayerLeft(PlayerInput player)
    {
        Debug.Log($"Player {player.playerIndex} left");
    }
}
```

Split-screen is configured on `PlayerInputManager`: set screen division (horizontal/vertical), borders, and per-player camera assignment happens automatically.

## Input Debugger

**Window > Analysis > Input Debugger** shows:

- All connected devices and their controls in real-time
- Active actions and their current values
- Remote device connections (for debugging on-device builds)
- Event traces for diagnosing input issues

Enable **Input Debug Mode** in Project Settings > Input System for additional diagnostics.

## Migration from Legacy Input

| Legacy (UnityEngine.Input) | New Input System |
|---------------------------|------------------|
| `Input.GetAxis("Horizontal")` | `moveAction.ReadValue<Vector2>().x` |
| `Input.GetButtonDown("Fire1")` | `fireAction.performed += ctx => ...` |
| `Input.GetKey(KeyCode.Space)` | `jumpAction.IsPressed()` |
| `Input.GetMouseButtonDown(0)` | Bind `<Mouse>/leftButton` to action |
| `Input.mousePosition` | `Mouse.current.position.ReadValue()` |
| `Input.GetJoystickNames()` | `Gamepad.all`, `InputSystem.devices` |
| `Input.GetAxisRaw("Vertical")` | Set composite mode to Digital |

### Step-by-Step Migration

1. Set Active Input Handling to **Both** during migration
2. Create Input Actions asset mirroring your old axes/buttons
3. Replace `Input.GetAxis()` calls one script at a time
4. Test each script after conversion
5. Once all scripts converted, switch to **Input System Package (New)** only
6. Remove `using UnityEngine.InputSystem;` is the new namespace (not `UnityEngine.Input`)

## Common Patterns

### Input Buffer (Coyote Time)

```csharp
float _jumpBufferTime = 0.15f;
float _jumpBufferTimer;

void OnJump(InputAction.CallbackContext ctx)
{
    if (ctx.performed) _jumpBufferTimer = _jumpBufferTime;
}

void Update()
{
    _jumpBufferTimer -= Time.deltaTime;
    if (_jumpBufferTimer > 0 && IsGrounded())
    {
        PerformJump();
        _jumpBufferTimer = 0;
    }
}
```

### Dead Zone Configuration

Set dead zones per binding in the Input Actions editor, or in code:

```csharp
// Stick dead zones (already handled by default processors)
// Add processor string to binding: "stickDeadzone(min=0.125,max=0.925)"

// Or apply at runtime:
InputSystem.settings.defaultDeadzoneMin = 0.125f;
InputSystem.settings.defaultDeadzoneMax = 0.925f;
```

### Action Map Switching for Game States

```csharp
public void EnterMenuState()
{
    _input.Player.Disable();
    _input.UI.Enable();
    Cursor.lockState = CursorLockMode.None;
    Cursor.visible = true;
}

public void EnterGameplayState()
{
    _input.UI.Disable();
    _input.Player.Enable();
    Cursor.lockState = CursorLockMode.Locked;
    Cursor.visible = false;
}
```
