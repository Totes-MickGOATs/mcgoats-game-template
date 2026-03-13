# Unity Animation

Reference guide for Unity's animation system. Covers Animator Controllers, Blend Trees,
layers, IK, root motion, Timeline, procedural tweening, and performance.

## Animation Clips

Animation clips store keyframe data for transforms, blendshapes, material properties, and more.

### Creating Clips

- **Animation window** (Ctrl+6): Record mode, add keyframes manually
- **Import from FBX/glTF**: Clips extracted from model files
- **Procedural**: Created at runtime via `AnimationClip` API

### Key Properties

| Property | Purpose |
|----------|---------|
| Loop Time | Whether clip loops |
| Root Transform Position/Rotation | Bake Into Pose for in-place animations |
| Curves | Custom float parameters driven by the clip |
| Events | Method calls at specific frames |

```csharp
// Runtime clip creation
AnimationClip clip = new AnimationClip();
clip.SetCurve("", typeof(Transform), "localPosition.x",
    AnimationCurve.Linear(0f, 0f, 1f, 5f));
```

## Animator Controller

The Animator Controller is a state machine that manages animation states and transitions.

### States

Each state plays an animation clip (or Blend Tree). Special states:
- **Entry**: Starting point, leads to default state
- **Any State**: Transitions from here fire regardless of current state
- **Exit**: Returns to the parent state machine (for sub-state machines)

### Parameters

Drive transitions and Blend Trees:

| Type | Use Case | Code Access |
|------|----------|-------------|
| Bool | Toggle states (isGrounded, isDead) | `animator.SetBool("isGrounded", true)` |
| Int | Indexed states (weaponType) | `animator.SetInteger("weaponType", 2)` |
| Float | Blended values (speed, direction) | `animator.SetFloat("speed", velocity.magnitude)` |
| Trigger | One-shot events (attack, jump) | `animator.SetTrigger("attack")` |

```csharp
// Driving the animator each frame
void Update()
{
    float speed = _rigidbody.velocity.magnitude;
    _animator.SetFloat("Speed", speed);
    _animator.SetBool("IsGrounded", _characterController.isGrounded);
    _animator.SetFloat("Direction", Input.GetAxis("Horizontal"));
}
```

### Transitions

| Setting | Purpose | Typical Value |
|---------|---------|---------------|
| Has Exit Time | Wait for clip to finish before transitioning | true for attacks, false for movement |
| Exit Time | Normalized time when transition can begin | 0.85 (near end of clip) |
| Transition Duration | Blend time (normalized or fixed) | 0.1 - 0.25s |
| Transition Offset | Start point in destination clip | 0 |
| Conditions | Parameter checks required | Speed > 0.1, IsGrounded == true |

**Best Practice:** Use **Fixed Duration** (seconds) rather than normalized for consistent feel regardless of clip length.

## Blend Trees

Blend Trees smoothly interpolate between multiple clips based on parameters.

### 1D Blend Tree

Blend by one parameter (e.g., speed):

```
Blend Tree (Speed):
  0.0 -> Idle
  0.5 -> Walk
  1.0 -> Run
  2.0 -> Sprint
```

### 2D Blend Trees

| Type | When to Use |
|------|------------|
| 2D Simple Directional | Each motion represents a unique direction (N, S, E, W) |
| 2D Freeform Directional | Multiple motions per direction at different speeds |
| 2D Freeform Cartesian | Parameters represent independent axes (speed + turn) |

```
2D Freeform Directional (SpeedX, SpeedY):
  (0, 0)   -> Idle
  (0, 1)   -> Walk Forward
  (0, 2)   -> Run Forward
  (0, -1)  -> Walk Backward
  (-1, 0)  -> Strafe Left
  (1, 0)   -> Strafe Right
```

```csharp
// Driving a 2D Blend Tree
Vector3 localVelocity = transform.InverseTransformDirection(_rigidbody.velocity);
_animator.SetFloat("VelocityX", localVelocity.x, 0.1f, Time.deltaTime);
_animator.SetFloat("VelocityZ", localVelocity.z, 0.1f, Time.deltaTime);
```

The `SetFloat` overload with damping (`dampTime`, `deltaTime`) provides smooth blending.

## Animation Layers

Layers allow multiple animations to play simultaneously on different body parts.

### Layer Setup

| Property | Purpose |
|----------|---------|
| Weight | Influence of this layer (0-1) |
| Blending | Override (replace) or Additive (add on top) |
| Avatar Mask | Which bones this layer affects |

**Common Layer Setup:**

| Layer | Blending | Mask | Purpose |
|-------|----------|------|---------|
| Base Layer | - | Full body | Locomotion |
| Upper Body | Override | Spine + Arms + Head | Aiming, holding weapon |
| Additive | Additive | Full body | Hit reactions, breathing |
| Face | Override | Head only | Facial expressions |

### Avatar Masks

Create via **Assets > Create > Avatar Mask**. Enable/disable specific bones:

```
Upper Body Mask:
  [x] Spine, Chest, Upper Chest
  [x] Left/Right Shoulder, Arm, Forearm, Hand
  [x] Head, Neck
  [ ] Hips, Left/Right Leg (disabled -- base layer handles these)
```

```csharp
// Runtime layer weight control
_animator.SetLayerWeight(1, isAiming ? 1f : 0f);  // Fade upper body layer
```

## Inverse Kinematics (IK)

IK adjusts bones to reach target positions, overriding the animation.

### Setup Requirements

1. Humanoid rig on the model
2. **IK Pass** enabled on the Animator layer
3. Override `OnAnimatorIK` in a script on the same GameObject

```csharp
public class FootIK : MonoBehaviour
{
    [SerializeField] float _footOffset = 0.1f;
    [SerializeField] LayerMask _groundLayer;

    Animator _animator;

    void Awake() => _animator = GetComponent<Animator>();

    void OnAnimatorIK(int layerIndex)
    {
        // Left foot placement
        PlaceFoot(AvatarIKGoal.LeftFoot);
        PlaceFoot(AvatarIKGoal.RightFoot);
    }

    void PlaceFoot(AvatarIKGoal foot)
    {
        _animator.SetIKPositionWeight(foot, 1f);
        _animator.SetIKRotationWeight(foot, 1f);

        Vector3 footPos = _animator.GetIKPosition(foot);
        if (Physics.Raycast(footPos + Vector3.up * 0.5f, Vector3.down,
            out RaycastHit hit, 1f, _groundLayer))
        {
            _animator.SetIKPosition(foot, hit.point + Vector3.up * _footOffset);
            _animator.SetIKRotation(foot,
                Quaternion.LookRotation(transform.forward, hit.normal));
        }
    }
}
```

### Look-At IK

```csharp
void OnAnimatorIK(int layerIndex)
{
    if (_lookTarget != null)
    {
        _animator.SetLookAtWeight(1f, 0.3f, 0.6f, 1f, 0.5f);
        // (weight, bodyWeight, headWeight, eyesWeight, clampWeight)
        _animator.SetLookAtPosition(_lookTarget.position);
    }
}
```

## Root Motion

Root Motion transfers the animation's root bone movement to the GameObject's transform.

### Setup

1. Check **Apply Root Motion** on the Animator component
2. Ensure clips have root motion baked (not "Bake Into Pose")

### OnAnimatorMove Override

Override default root motion application for custom control:

```csharp
public class RootMotionController : MonoBehaviour
{
    Animator _animator;
    CharacterController _controller;

    void Awake()
    {
        _animator = GetComponent<Animator>();
        _controller = GetComponent<CharacterController>();
    }

    void OnAnimatorMove()
    {
        // Apply root motion through CharacterController instead of Transform
        Vector3 velocity = _animator.deltaPosition / Time.deltaTime;
        velocity.y = _currentVerticalSpeed; // Preserve gravity
        _controller.Move(velocity * Time.deltaTime);
        transform.rotation *= _animator.deltaRotation;
    }
}
```

## Animator Override Controller

Reuse the same state machine with different clips. Ideal for character variants:

```csharp
// Runtime clip swapping
AnimatorOverrideController overrideController =
    new AnimatorOverrideController(_animator.runtimeAnimatorController);

overrideController["DefaultIdle"] = customIdleClip;
overrideController["DefaultRun"] = customRunClip;
_animator.runtimeAnimatorController = overrideController;
```

Create via **Assets > Create > Animator Override Controller**, assign the original controller, then drag replacement clips.

## Animation Events

Call methods from specific frames in the animation:

1. Select the clip in the Animation window
2. Move the playhead to the desired frame
3. Click **Add Event** and select a method

```csharp
// Methods called by animation events (must be on same GameObject as Animator)
public class CombatAnimEvents : MonoBehaviour
{
    public void OnAttackHitFrame()
    {
        // Check for hits at the moment of impact
        Collider[] hits = Physics.OverlapSphere(
            _hitPoint.position, _hitRadius, _enemyLayer);
        foreach (var hit in hits)
            hit.GetComponent<IDamageable>()?.TakeDamage(_damage);
    }

    public void OnFootstep()
    {
        _audioSource.PlayOneShot(_footstepClips[Random.Range(0, _footstepClips.Length)]);
    }
}
```

## Animation Rigging Package

Advanced runtime rigging constraints:

```json
"com.unity.animation.rigging": "1.3.0"
```

### Key Constraints

| Constraint | Purpose |
|-----------|---------|
| Multi-Aim Constraint | Aim a bone at a target (head tracking, turret) |
| Two Bone IK Constraint | Classic IK chain (hand to grip, foot to ground) |
| Damped Transform | Smooth follow (tail, chain, hair) |
| Override Transform | Snap a bone to a target (hand on weapon grip) |
| Multi-Parent Constraint | Switch parent at runtime (pick up / put down) |

```
// Hierarchy for Rig setup:
Character
  +-- Rig (Rig component, RigBuilder reference)
  |     +-- HeadAimConstraint (Multi-Aim Constraint)
  |     +-- LeftHandIK (Two Bone IK Constraint)
  |     +-- RightHandGrip (Override Transform)
  +-- Model (Animator + Rig Builder)
```

## Timeline

Cinematic sequencing system for scripted scenes.

### Core Components

| Component | Purpose |
|-----------|---------|
| PlayableDirector | Controls playback, binds tracks to scene objects |
| Timeline Asset | Reusable sequence of tracks (.playable file) |

### Track Types

| Track | Purpose |
|-------|---------|
| Animation Track | Play clips on an Animator |
| Activation Track | Enable/disable GameObjects on a schedule |
| Audio Track | Play AudioClips |
| Signal Track | Fire events at specific times |
| Cinemachine Track | Control camera shots (via CinemachineBrain) |
| Control Track | Manage sub-timelines, particle systems, ITimeControl |

```csharp
// Controlling Timeline from code
[SerializeField] PlayableDirector _director;

void StartCutscene()
{
    _director.Play();
}

void SkipCutscene()
{
    _director.time = _director.duration;
    _director.Evaluate();
    _director.Stop();
}

// Signal receiver -- responds to Signal Track events
public class CutsceneSignalReceiver : MonoBehaviour, INotificationReceiver
{
    public void OnNotify(Playable origin, INotification notification, object context)
    {
        // Handle signal
    }
}
```

## Procedural Animation (DOTween/LeanTween)

For UI animations, VFX, and procedural object movement:

```csharp
// DOTween examples (com.demigiant.dotween)
transform.DOMove(targetPos, 1f).SetEase(Ease.OutBounce);
transform.DORotate(new Vector3(0, 360, 0), 2f, RotateMode.FastBeyond360);
transform.DOScale(1.5f, 0.5f).SetLoops(-1, LoopType.Yoyo);

// Sequences
Sequence seq = DOTween.Sequence();
seq.Append(transform.DOMove(posA, 0.5f));
seq.Append(transform.DOMove(posB, 0.5f));
seq.Join(transform.DORotate(Vector3.up * 180, 0.5f)); // Parallel with previous
seq.AppendCallback(() => Debug.Log("Sequence complete"));

// UI
canvasGroup.DOFade(0f, 0.3f);
rectTransform.DOAnchorPos(new Vector2(100, 0), 0.5f);
```

### Easing Functions

Common choices: `Ease.OutQuad` (decelerate), `Ease.InOutCubic` (smooth), `Ease.OutBack` (overshoot), `Ease.OutElastic` (bounce).

## Humanoid vs Generic Rig

| | Humanoid | Generic |
|-|----------|---------|
| Retargeting | Yes -- share animations across models | No -- animations are model-specific |
| IK | Built-in IK goals (hands, feet, look-at) | Requires Animation Rigging |
| Performance | Slightly more expensive (muscle space) | Faster |
| Use For | Characters (bipedal) | Props, creatures, vehicles |

### Avatar Setup

For Humanoid rigs, configure the Avatar in the model import settings:
1. Set Animation Type to **Humanoid**
2. Click **Configure** to verify bone mapping
3. Resolve any red/missing bones
4. Set muscle limits if needed (e.g., restrict head rotation range)

## Performance

### Animator Culling Mode

| Mode | Behavior | Use For |
|------|----------|---------|
| Always Animate | Full update even when off-screen | Main character, audio-synced |
| Cull Update Transforms | Skip transform writes when invisible | Most NPCs |
| Cull Completely | Stop animation entirely when invisible | Background characters |

### Optimization Tips

- **Optimize Game Objects**: In model import, enables internal optimization of the bone hierarchy. Exposes only the bones you explicitly mark.
- **Write Defaults**: Disable per-state to prevent unexpected blending artifacts. Choose a consistent approach across the project (all on or all off).
- **Animator.keepAnimatorStateOnDisable**: Set to `true` if you need to preserve state when toggling the Animator.
- **State Machine Behaviours**: Use sparingly. `OnStateEnter`/`OnStateExit` run on the main thread and can cause GC if allocating.

```csharp
// State Machine Behaviour
public class AttackStateBehaviour : StateMachineBehaviour
{
    override public void OnStateEnter(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        animator.GetComponent<CombatController>().OnAttackStart();
    }

    override public void OnStateExit(Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        animator.GetComponent<CombatController>().OnAttackEnd();
    }
}
```
