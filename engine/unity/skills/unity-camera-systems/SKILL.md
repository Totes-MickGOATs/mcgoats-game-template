# Unity Camera Systems

Reference guide for camera systems in Unity using Cinemachine. Covers virtual cameras,
body/aim algorithms, state-driven cameras, blending, and advanced techniques.

## Package Setup

```json
// Packages/manifest.json
"com.unity.cinemachine": "3.1.2"
```

**Version Note:**
- Cinemachine 3.x: Unity 2023.1+ -- renamed components (CinemachineCamera, CinemachineFollow, etc.)
- Cinemachine 2.x: Unity 2019-2022 -- original names (CinemachineVirtualCamera, CinemachineTransposer, etc.)

This guide uses Cinemachine 3.x naming. The 2.x equivalents are noted where they differ significantly.

## Core Architecture

Cinemachine separates camera logic from the actual Unity Camera:

```
Unity Camera (with CinemachineBrain)
    |
    +-- evaluates all active CinemachineCameras
    |
    +-- picks the highest-priority camera
    |
    +-- blends between cameras on transitions
```

**CinemachineBrain** (on the main Camera): orchestrates blending, picks the active virtual camera.
**CinemachineCamera** (on separate GameObjects): defines how the camera should behave. Only one is "live" at a time.

```csharp
// Basic setup hierarchy:
// MainCamera (Camera + CinemachineBrain)
// FollowCam (CinemachineCamera + CinemachineFollow + CinemachineRotationComposer)
// OverviewCam (CinemachineCamera + CinemachinePositionComposer)
```

## CinemachineCamera Setup

Each CinemachineCamera needs at minimum a **body** behavior (how it moves) and optionally an **aim** behavior (where it looks).

### Inspector Properties

| Property | Purpose |
|----------|---------|
| Follow | Target transform the camera follows |
| LookAt | Target transform the camera aims at |
| Lens | FOV, near/far clip, orthographic size |
| Priority | Higher priority cameras take precedence |
| Standby Update | How to update when not live (Never, Always, Round Robin) |

### Enabling/Disabling

```csharp
// Switch cameras by adjusting priority or enabling/disabling
[SerializeField] CinemachineCamera _followCam;
[SerializeField] CinemachineCamera _overviewCam;

public void SwitchToOverview()
{
    _followCam.Priority = 0;
    _overviewCam.Priority = 10;
}

// Or simply:
_followCam.enabled = false;
_overviewCam.enabled = true;
```

## Body Algorithms (Positioning)

Body components control how the camera positions itself relative to the Follow target.

### CinemachineFollow (Transposer in 2.x)

Maintains a fixed offset from the target in the target's local space.

```
CinemachineFollow:
  Follow Offset: (0, 5, -10)    // Behind and above
  Damping: (1, 1, 1)             // Smooth follow delay
  Binding Mode: Lock To Target With World Up
```

**Binding Modes:**

| Mode | Behavior | Use Case |
|------|----------|----------|
| Lock To Target With World Up | Offset rotates with target yaw only | 3rd-person character |
| Lock To Target | Full rotation tracking | Vehicle chase cam |
| World Space | Offset is absolute | Fixed-offset overview |
| Lazy Follow | Only follows when target moves far enough | Relaxed exploration |

### CinemachinePositionComposer (Framing Transposer in 2.x)

Keeps the target within a screen-space frame. Ideal for 2.5D sidescrollers and third-person.

```
CinemachinePositionComposer:
  Tracked Object Offset: (0, 1.5, 0)   // Aim at character head
  Lookahead Time: 0.3                    // Anticipate movement
  Screen Position: (0.5, 0.5)           // Center of screen
  Dead Zone: (0.1, 0.1)                 // No movement in this region
  Soft Zone: (0.8, 0.8)                 // Gradual correction zone
  Damping: 2                            // Smoothing strength
  Camera Distance: 10
```

**Dead Zone:** Target can move here without camera reacting.
**Soft Zone:** Camera gradually corrects to keep target here.
**Hard Limit:** Outside this, camera moves immediately (no damping).

### CinemachineOrbitalFollow (Orbital Transposer in 2.x)

Orbits around the target, driven by input axes.

```csharp
// Orbital follow with player-controlled rotation
CinemachineOrbitalFollow orbital = vcam.GetComponent<CinemachineOrbitalFollow>();

// Input is typically wired via CinemachineInputAxisController component
// or driven manually:
public class CameraOrbitInput : MonoBehaviour, IInputAxisOwner
{
    public void GetInputAxis(int axis, out float value)
    {
        // axis 0 = horizontal, axis 1 = vertical
        value = axis == 0 ? Input.GetAxis("Mouse X") : Input.GetAxis("Mouse Y");
    }
}
```

## Aim Algorithms (Rotation)

### CinemachineRotationComposer (Composer in 2.x)

Rotates the camera to keep the LookAt target in a screen-space zone.

```
CinemachineRotationComposer:
  Tracked Object Offset: (0, 0, 0)
  Lookahead Time: 0
  Screen Position: (0.5, 0.6)    // Slightly above center
  Dead Zone: (0.1, 0.05)
  Soft Zone: (0.5, 0.5)
  Damping: (0.5, 0.5)
```

### CinemachineGroupFraming (Group Composer in 2.x)

Frames multiple targets automatically. Use with a CinemachineTargetGroup as LookAt.

```csharp
// CinemachineTargetGroup on a separate GameObject
// Add targets with weight and radius:
[SerializeField] CinemachineTargetGroup _targetGroup;

void AddPlayer(Transform player)
{
    _targetGroup.AddMember(player, 1f, 2f); // weight, radius
}

void RemovePlayer(Transform player)
{
    _targetGroup.RemoveMember(player);
}
```

```
CinemachineGroupFraming:
  Framing Size: 0.8              // How much screen to fill
  Framing Mode: Horizontal And Vertical
  Damping: 2
  Size Adjustment: Dolly Then Zoom
  Lateral Adjustment: 0.5
```

### Hard Look At

Simply points at the LookAt target with zero damping. Good for locked-on targeting.

## CinemachineBrain -- Blending

The Brain controls how transitions between cameras look.

### Default Blend

```
CinemachineBrain:
  Default Blend:
    Style: Ease In Out
    Duration: 2.0
  Update Method: Smart Update     // Handles mixed Update/FixedUpdate targets
  Blend Update Method: Late Update
```

### Custom Blends

Create a **CinemachineBlenderSettings** asset to define per-camera-pair blends:

```
From            To              Style           Duration
FollowCam       OverviewCam     Cut             0
OverviewCam     FollowCam       Ease In Out     1.5
*               CutsceneCam     Ease In         0.5
```

Assign this asset to the CinemachineBrain's Custom Blends field.

### Blend Styles

| Style | Behavior |
|-------|----------|
| Cut | Instant switch |
| Ease In Out | Smooth acceleration and deceleration |
| Ease In | Smooth start, abrupt end |
| Ease Out | Abrupt start, smooth end |
| Hard In | Fast start, slow end |
| Hard Out | Slow start, fast end |
| Linear | Constant speed |
| Custom | AnimationCurve |

## State-Driven Camera

Tie cameras to Animator states for automatic context switching:

```
CinemachineStateDrivenCamera:
  Animated Target: [Character Animator]
  Default Blend: Ease In Out, 0.5s

  State-Camera Map:
    Idle       -> IdleCam (close, low angle)
    Running    -> RunCam (pulled back, slight lag)
    Jumping    -> AirCam (wider FOV)
    Combat     -> CombatCam (over-shoulder)
```

Each child camera is a full CinemachineCamera with its own body/aim. The state machine selects which is live.

## FreeLook Camera (3-Rig Orbit)

Classic third-person orbit with three height rings:

```
CinemachineCamera + CinemachineOrbitalFollow + CinemachineRotationComposer:

  Orbits:
    Top Rig:    Height = 4.5,  Radius = 1.75
    Middle Rig: Height = 2.5,  Radius = 3.0
    Bottom Rig: Height = 0.4,  Radius = 1.3

  Spline Curvature: 0.5
```

The player's vertical input blends between rigs. Horizontal input orbits around the target.

## Camera Shake and Impulse

### Noise Profiles

Add `CinemachineBasicMultiChannelPerlin` to a camera for continuous shake:

```
CinemachineBasicMultiChannelPerlin:
  Noise Profile: 6D Shake       // Built-in preset
  Amplitude Gain: 0.5
  Frequency Gain: 1.0
```

Built-in profiles: Handheld Normal, Handheld Strong, 6D Shake, Wobble.

### Cinemachine Impulse (One-Shot Shake)

```csharp
// On the source of the shake (explosion, landing, hit):
[SerializeField] CinemachineImpulseSource _impulseSource;

void OnExplosion()
{
    _impulseSource.GenerateImpulse(); // Uses configured default velocity
}

void OnHeavyLanding(float impactForce)
{
    _impulseSource.GenerateImpulse(Vector3.down * impactForce);
}
```

On the camera, add `CinemachineImpulseListener`:

```
CinemachineImpulseListener:
  Channel Mask: 1               // Which impulse channels to react to
  Gain: 1.0
  Use 2D Distance: false
```

## Confiner and Dolly

### CinemachineConfiner

Keeps the camera within a bounding volume:

```
CinemachineConfiner:
  Bounding Volume: [Collider reference]    // Box, Sphere, or Composite
  Damping: 0.5
  Slow Speed: 0                            // Speed below which confiner relaxes
```

For 2D: use a PolygonCollider2D (on a non-trigger, non-physics layer).

### Dolly Track

Move the camera along a predefined path:

```
CinemachineCamera + CinemachineSplineDolly:
  Spline: [SplineContainer reference]
  Camera Position:
    Position Units: Normalized    // 0-1 along path
    Speed: 0                     // 0 = driven by code or automation
  Auto Dolly:
    Enabled: true
    Method: Nearest Point To Target  // Camera travels to closest point on path
```

```csharp
// Manual dolly control
CinemachineSplineDolly dolly = vcam.GetComponent<CinemachineSplineDolly>();
dolly.CameraPosition = Mathf.Lerp(dolly.CameraPosition, targetPosition, Time.deltaTime);
```

## Timeline Integration

Cinemachine integrates with Timeline for cinematic sequences:

1. Add a **Cinemachine Track** to the Timeline
2. Set the track's binding to the CinemachineBrain's GameObject
3. Drag CinemachineCamera clips onto the track
4. Overlapping clips create automatic blends

```csharp
// Triggering a cutscene
[SerializeField] PlayableDirector _cutsceneDirector;
[SerializeField] CinemachineCamera _gameplayCam;

void StartCutscene()
{
    _gameplayCam.Priority = 0; // Let timeline cameras take over
    _cutsceneDirector.Play();
    _cutsceneDirector.stopped += OnCutsceneEnd;
}

void OnCutsceneEnd(PlayableDirector director)
{
    _gameplayCam.Priority = 10;
    director.stopped -= OnCutsceneEnd;
}
```

## Screen-to-World Conversion

Essential for mouse interaction, raycasting, and targeting:

```csharp
// Raycast from screen point
Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
if (Physics.Raycast(ray, out RaycastHit hit, 100f))
{
    Debug.Log($"Hit: {hit.collider.name} at {hit.point}");
}

// Screen to world position at a specific distance
Vector3 worldPos = Camera.main.ScreenToWorldPoint(
    new Vector3(Input.mousePosition.x, Input.mousePosition.y, 10f));

// World to screen position (for UI tracking)
Vector3 screenPos = Camera.main.WorldToScreenPoint(target.position);
bool isOnScreen = screenPos.z > 0
    && screenPos.x > 0 && screenPos.x < Screen.width
    && screenPos.y > 0 && screenPos.y < Screen.height;
```

## Multiple Cameras

### Render Order (Built-in Pipeline)

```csharp
// Lower depth renders first, higher renders on top
mainCamera.depth = 0;
uiCamera.depth = 1;       // Renders UI on top
minimapCamera.depth = 2;  // Minimap overlay
```

Set each camera's **Clear Flags** and **Culling Mask** appropriately:
- Main camera: Skybox, everything except UI layer
- UI camera: Depth Only, UI layer only
- Minimap camera: Solid Color, renders to RenderTexture

### Camera Stacking (URP)

```
Main Camera (Base):
  Render Type: Base
  Stack: [OverlayCamera1, OverlayCamera2]

Overlay Camera 1 (UI):
  Render Type: Overlay
  Culling Mask: UI

Overlay Camera 2 (Effects):
  Render Type: Overlay
  Culling Mask: Effects
```

URP camera stacking is the proper way to layer cameras. Avoid multiple Base cameras.

## Common Patterns

### Smooth Camera Transition Helper

```csharp
public static class CameraHelper
{
    public static void SwitchTo(CinemachineCamera cam, int priority = 10)
    {
        // Lower all other cameras, raise this one
        foreach (var vc in CinemachineCore.GetAllCameras())
            vc.Priority = 0;
        cam.Priority = priority;
    }
}
```

### Look-At Target Offset for Aiming

```csharp
// Shift the camera's LookAt target toward crosshair during aiming
CinemachineRotationComposer composer = vcam.GetComponent<CinemachineRotationComposer>();

void Update()
{
    float aimInfluence = isAiming ? 1f : 0f;
    composer.ScreenPosition = Vector2.Lerp(
        new Vector2(0.5f, 0.5f),     // Centered (hip fire)
        new Vector2(0.35f, 0.55f),   // Over-shoulder (ADS)
        aimInfluence);
}
```

### Cinemachine Camera Priorities by Context

| Context | Camera | Priority |
|---------|--------|----------|
| Default gameplay | FollowCam | 10 |
| Aiming/ADS | AimCam | 15 |
| Cutscene | CutsceneCam | 20 |
| Death/spectate | SpectatorCam | 25 |
| Menu/pause | MenuCam | 5 |

Higher priority = becomes live. When a camera is deactivated or lowered, the Brain blends back to the next highest.
