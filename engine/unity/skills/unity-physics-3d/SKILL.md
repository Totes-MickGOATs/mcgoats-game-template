# Unity 3D Physics

Comprehensive guide to 3D physics in Unity using PhysX (Built-in/URP) or Havok (DOTS).

## Rigidbody Fundamentals

The `Rigidbody` component makes a GameObject participate in physics simulation.

### Key Properties

| Property | Default | Purpose |
|----------|---------|---------|
| `mass` | 1 | Mass in kg. Affects force calculations, not gravity fall speed |
| `drag` | 0 | Linear air resistance. 0 = no drag, higher = slower movement |
| `angularDrag` | 0.05 | Rotational air resistance |
| `useGravity` | true | Whether gravity affects this body |
| `isKinematic` | false | If true, not driven by physics — moved only via transform or `MovePosition` |
| `interpolation` | None | Smoothing between physics steps for visual jitter reduction |
| `collisionDetectionMode` | Discrete | CCD mode for fast-moving objects |

### Interpolation Modes

```csharp
// None — no smoothing, can appear jittery at low fixed timestep
rb.interpolation = RigidbodyInterpolation.None;

// Interpolate — smooths based on previous frame positions (slight lag, most stable)
rb.interpolation = RigidbodyInterpolation.Interpolate;

// Extrapolate — predicts next position (no lag, can overshoot)
rb.interpolation = RigidbodyInterpolation.Extrapolate;
```

**Rule of thumb:** Use `Interpolate` on the player-controlled body. Leave others at `None`.

### Kinematic vs Dynamic

```csharp
// Dynamic — physics engine moves it, responds to forces/collisions
rb.isKinematic = false;

// Kinematic — you move it, still generates collision events
// Use for: moving platforms, doors, elevators
rb.isKinematic = true;
rb.MovePosition(targetPos);   // Use this, NOT transform.position
rb.MoveRotation(targetRot);   // Use this, NOT transform.rotation
```

### Constraints

Lock position or rotation on specific axes:

```csharp
rb.constraints = RigidbodyConstraints.FreezePositionY
               | RigidbodyConstraints.FreezeRotationX
               | RigidbodyConstraints.FreezeRotationZ;
```

## Colliders

Every physics-interacting object needs at least one collider.

### Primitive Colliders (Preferred for Performance)

```
BoxCollider       — walls, crates, floors, platforms
SphereCollider    — balls, pickups, spherical triggers
CapsuleCollider   — characters, projectiles, cylindrical objects
```

### MeshCollider

```csharp
// Convex — required for Rigidbody, max 255 triangles, closed shape
meshCollider.convex = true;

// Non-convex (concave) — static geometry only (no Rigidbody)
// Use for: terrain-like static meshes, level geometry
meshCollider.convex = false;
```

**Performance hierarchy:** Sphere > Capsule > Box > Convex Mesh > Concave Mesh.

### Compound Colliders

Attach multiple primitive colliders on child GameObjects. Physics treats them as one body:

```
Player (Rigidbody)
  ├── Body (BoxCollider)
  ├── Head (SphereCollider)
  └── Feet (SphereCollider)
```

### Terrain Collider

Automatically generated from Unity Terrain heightmap. Efficient for large terrains but cannot be convex.

## Collision Layers and Layer Masks

### Setup in Project Settings

Edit via **Edit > Project Settings > Physics > Layer Collision Matrix**.

```csharp
// Assign layer in code
gameObject.layer = LayerMask.NameToLayer("Vehicles");

// Create layer mask for raycasts
int groundMask = LayerMask.GetMask("Ground", "Terrain");
int everythingExceptUI = ~LayerMask.GetMask("UI");
```

### Recommended Layer Layout

| Layer | Name | Collides With |
|-------|------|---------------|
| 0 | Default | Everything |
| 6 | Terrain | Vehicles, Players, Projectiles |
| 7 | Vehicles | Terrain, Vehicles, Obstacles |
| 8 | Players | Terrain, Obstacles, Pickups |
| 9 | Projectiles | Terrain, Obstacles, Players (not self) |
| 10 | Triggers | Players, Vehicles |
| 11 | Obstacles | Everything except Triggers |

### Layer Mask in Raycasts

```csharp
int layerMask = LayerMask.GetMask("Ground", "Obstacles");
if (Physics.Raycast(origin, direction, out RaycastHit hit, maxDistance, layerMask))
{
    Debug.Log($"Hit {hit.collider.name} at {hit.point}");
}
```

## FixedUpdate — The Physics Loop

**All physics code goes in `FixedUpdate`, never `Update`.**

```csharp
void FixedUpdate()
{
    // Runs at fixed intervals (default 50Hz = 0.02s)
    // Use Time.fixedDeltaTime for calculations
    rb.AddForce(Vector3.forward * speed * Time.fixedDeltaTime, ForceMode.Force);
}

void Update()
{
    // Variable framerate — for input reading, visuals, UI
    // NEVER apply forces or move rigidbodies here
    float h = Input.GetAxis("Horizontal"); // Read input here
}
```

### Timestep Configuration

```csharp
// Project Settings > Time > Fixed Timestep
Time.fixedDeltaTime = 0.02f;   // 50 Hz (default)
Time.fixedDeltaTime = 0.01f;   // 100 Hz (more accurate, more CPU)
```

For vehicle or fighting games, consider 100 Hz. For casual games, 50 Hz is fine.

## Applying Forces

### ForceMode Options

```csharp
// Force — continuous force, affected by mass. Use for engines, wind.
rb.AddForce(direction * 100f, ForceMode.Force);

// Impulse — instant kick, affected by mass. Use for explosions, jumps.
rb.AddForce(Vector3.up * 5f, ForceMode.Impulse);

// Acceleration — continuous, ignores mass. Use for uniform gravity zones.
rb.AddForce(direction * 10f, ForceMode.Acceleration);

// VelocityChange — instant, ignores mass. Use for dash, teleport-like movement.
rb.AddForce(direction * 5f, ForceMode.VelocityChange);
```

### Torque

```csharp
rb.AddTorque(Vector3.up * turnForce, ForceMode.Force);        // Spin around Y
rb.AddRelativeTorque(Vector3.up * turnForce, ForceMode.Force); // Relative to local axes
```

### Direct Velocity (Use Sparingly)

```csharp
// Override velocity directly — breaks physics realism but useful for snappy movement
rb.velocity = new Vector3(rb.velocity.x, jumpSpeed, rb.velocity.z);
```

## Joints

### Joint Types

| Joint | Use Case | Example |
|-------|----------|---------|
| `FixedJoint` | Weld two bodies together | Attached cargo, compound objects |
| `HingeJoint` | Single-axis rotation | Doors, wheels, pendulums |
| `SpringJoint` | Elastic connection | Bungee, suspension, tethered objects |
| `ConfigurableJoint` | Full control over all 6 DOF | Vehicle suspension, ragdoll, robotic arms |
| `CharacterJoint` | Humanoid joint limits | Ragdoll limbs |

### Hinge Joint Example

```csharp
var hinge = gameObject.AddComponent<HingeJoint>();
hinge.connectedBody = frameRigidbody;
hinge.axis = Vector3.up;                  // Rotation axis
hinge.useLimits = true;
hinge.limits = new JointLimits { min = -90f, max = 90f };
hinge.useMotor = true;
hinge.motor = new JointMotor { targetVelocity = 100f, force = 50f };
```

### Configurable Joint (Vehicle Suspension)

```csharp
var joint = gameObject.AddComponent<ConfigurableJoint>();
joint.connectedBody = chassisRb;

// Lock X and Z, free Y for suspension travel
joint.xMotion = ConfigurableJointMotion.Locked;
joint.yMotion = ConfigurableJointMotion.Limited;
joint.zMotion = ConfigurableJointMotion.Locked;

// Spring on Y axis
var drive = new JointDrive
{
    positionSpring = 5000f,
    positionDamper = 200f,
    maximumForce = float.MaxValue
};
joint.yDrive = drive;
```

## Raycasting

### Basic Raycast

```csharp
if (Physics.Raycast(transform.position, transform.forward, out RaycastHit hit, 100f))
{
    Debug.Log($"Hit: {hit.collider.name}, Distance: {hit.distance}, Normal: {hit.normal}");
    Debug.DrawLine(transform.position, hit.point, Color.red, 1f);
}
```

### Shape Casts

```csharp
// SphereCast — thick raycast, good for ground checks
Physics.SphereCast(origin, radius, direction, out hit, maxDistance, layerMask);

// BoxCast — rectangular sweep
Physics.BoxCast(center, halfExtents, direction, out hit, orientation, maxDistance, layerMask);

// CapsuleCast — capsule sweep, good for character movement
Physics.CapsuleCast(point1, point2, radius, direction, out hit, maxDistance, layerMask);
```

### RaycastAll and RaycastNonAlloc

```csharp
// Returns ALL hits (allocates array — avoid in hot paths)
RaycastHit[] hits = Physics.RaycastAll(origin, direction, maxDistance, layerMask);

// Non-allocating version (pre-allocate buffer)
RaycastHit[] buffer = new RaycastHit[16];
int count = Physics.RaycastNonAlloc(origin, direction, buffer, maxDistance, layerMask);
for (int i = 0; i < count; i++)
{
    // Process buffer[i]
}
```

### Overlap Tests

```csharp
// Check what's inside a sphere (explosions, area detection)
Collider[] results = new Collider[32];
int count = Physics.OverlapSphereNonAlloc(center, radius, results, layerMask);

// Box overlap
Physics.OverlapBoxNonAlloc(center, halfExtents, results, orientation, layerMask);
```

## Triggers vs Collisions

### Triggers (isTrigger = true)

Pass-through volumes. Use for: pickup zones, damage areas, checkpoints.

```csharp
// At least one object needs a Rigidbody (can be kinematic)
void OnTriggerEnter(Collider other)  { /* First frame of overlap */ }
void OnTriggerStay(Collider other)   { /* Every fixed frame while overlapping */ }
void OnTriggerExit(Collider other)   { /* First frame after separation */ }
```

### Collisions (isTrigger = false)

Physical contact. Use for: ground detection, impact damage, bounce.

```csharp
void OnCollisionEnter(Collision collision)
{
    float impactForce = collision.impulse.magnitude / Time.fixedDeltaTime;
    ContactPoint contact = collision.GetContact(0);
    Vector3 hitPoint = contact.point;
    Vector3 hitNormal = contact.normal;
}
void OnCollisionStay(Collision collision)  { /* Ongoing contact */ }
void OnCollisionExit(Collision collision)  { /* Separation */ }
```

### Collision Matrix Requirements

| | Static Collider | Kinematic Rigidbody | Dynamic Rigidbody |
|---|---|---|---|
| **Static Collider** | No | Trigger only | Yes |
| **Kinematic Rigidbody** | Trigger only | Trigger only | Yes |
| **Dynamic Rigidbody** | Yes | Yes | Yes |

## Physics Materials

Create via **Assets > Create > Physic Material**.

```csharp
PhysicMaterial mat = new PhysicMaterial("Ice");
mat.staticFriction = 0.05f;     // Friction when stationary
mat.dynamicFriction = 0.03f;    // Friction when moving
mat.bounciness = 0.1f;          // 0 = no bounce, 1 = perfect bounce
mat.frictionCombine = PhysicMaterialCombine.Minimum;   // How two materials combine
mat.bounceCombine = PhysicMaterialCombine.Maximum;

collider.material = mat;
```

### Combine Modes

| Mode | Result |
|------|--------|
| Average | (a + b) / 2 |
| Minimum | min(a, b) |
| Maximum | max(a, b) |
| Multiply | a * b |

Priority: Average < Minimum < Multiply < Maximum. The higher-priority mode wins.

## PhysX Settings

**Edit > Project Settings > Physics:**

| Setting | Default | Notes |
|---------|---------|-------|
| Gravity | (0, -9.81, 0) | Change for moon/space games |
| Default Solver Iterations | 6 | Increase for stable joints/stacking |
| Default Solver Velocity Iterations | 1 | Increase for jitter-free contacts |
| Auto Sync Transforms | true | Set false for performance, call `Physics.SyncTransforms()` manually |
| Reuse Collision Callbacks | true | Reduces GC in collision callbacks |

## Common Gotchas

### Moving Colliders Without Rigidbody

Moving a static collider forces PhysX to rebuild its spatial tree. Add a `Rigidbody` with `isKinematic = true` instead:

```csharp
// BAD — moving static collider every frame
transform.position += Vector3.right * Time.deltaTime;

// GOOD — kinematic rigidbody
rb.MovePosition(rb.position + Vector3.right * Time.fixedDeltaTime);
```

### Scale on Colliders

Non-uniform scale on MeshColliders is expensive. Bake scale into the mesh or use primitive colliders.

### MeshCollider + Rigidbody

A `MeshCollider` on a dynamic Rigidbody **must** be convex. Non-convex MeshColliders are static only.

### Rigidbody on Parent Only

Place the Rigidbody on the root. Child colliders automatically become part of the compound collider. Do NOT put Rigidbodies on children unless you want separate physics bodies.

### Collision Detection Modes

```csharp
// Discrete — default, can tunnel through thin objects at high speed
rb.collisionDetectionMode = CollisionDetectionMode.Discrete;

// Continuous — prevents tunneling for this body vs static colliders
rb.collisionDetectionMode = CollisionDetectionMode.Continuous;

// ContinuousDynamic — prevents tunneling vs static AND dynamic colliders (expensive)
rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;

// ContinuousSpeculative — cheaper CCD, works with kinematic too
rb.collisionDetectionMode = CollisionDetectionMode.ContinuousSpeculative;
```

## Vehicle Physics: WheelCollider

Unity's built-in vehicle physics uses `WheelCollider` — a raycast-based suspension + tire model.

### Basic Setup

```csharp
public class SimpleVehicle : MonoBehaviour
{
    [SerializeField] private WheelCollider[] driveWheels;
    [SerializeField] private WheelCollider[] steerWheels;
    [SerializeField] private float maxMotorTorque = 400f;
    [SerializeField] private float maxSteerAngle = 30f;
    [SerializeField] private float maxBrakeTorque = 1000f;

    void FixedUpdate()
    {
        float throttle = Input.GetAxis("Vertical");
        float steer = Input.GetAxis("Horizontal");
        bool brake = Input.GetKey(KeyCode.Space);

        foreach (var wheel in steerWheels)
            wheel.steerAngle = steer * maxSteerAngle;

        foreach (var wheel in driveWheels)
        {
            wheel.motorTorque = throttle * maxMotorTorque;
            wheel.brakeTorque = brake ? maxBrakeTorque : 0f;
        }
    }
}
```

### WheelCollider Properties

| Property | Purpose |
|----------|---------|
| `radius` | Wheel radius in meters |
| `suspensionDistance` | Max suspension travel |
| `suspensionSpring` | Spring/damper/target position |
| `forwardFriction` | Longitudinal grip curve |
| `sidewaysFriction` | Lateral grip curve |
| `mass` | Wheel mass (affects suspension) |

### Syncing Visual Wheels

```csharp
void UpdateWheelVisual(WheelCollider collider, Transform visual)
{
    collider.GetWorldPose(out Vector3 pos, out Quaternion rot);
    visual.position = pos;
    visual.rotation = rot;
}
```

### Suspension Tuning

```csharp
JointSpring spring = wheel.suspensionSpring;
spring.spring = 35000f;        // Spring force (higher = stiffer)
spring.damper = 4500f;         // Damping (higher = less oscillation)
spring.targetPosition = 0.5f;  // 0 = fully extended, 1 = fully compressed
wheel.suspensionSpring = spring;
wheel.suspensionDistance = 0.3f; // Travel distance in meters
```

### Anti-Roll Bar (Stabilizer)

```csharp
void ApplyAntiRollBar(WheelCollider leftWheel, WheelCollider rightWheel, float antiRollForce)
{
    float travelL = 1f, travelR = 1f;

    if (leftWheel.GetGroundHit(out WheelHit hitL))
        travelL = (-leftWheel.transform.InverseTransformPoint(hitL.point).y
                   - leftWheel.radius) / leftWheel.suspensionDistance;

    if (rightWheel.GetGroundHit(out WheelHit hitR))
        travelR = (-rightWheel.transform.InverseTransformPoint(hitR.point).y
                   - rightWheel.radius) / rightWheel.suspensionDistance;

    float antiRoll = (travelL - travelR) * antiRollForce;

    if (leftWheel.isGrounded)
        rb.AddForceAtPosition(leftWheel.transform.up * -antiRoll, leftWheel.transform.position);
    if (rightWheel.isGrounded)
        rb.AddForceAtPosition(rightWheel.transform.up * antiRoll, rightWheel.transform.position);
}
```

## Performance Tips

1. **Use primitive colliders** over MeshColliders whenever possible
2. **Pre-allocate raycast buffers** with `NonAlloc` variants in hot paths
3. **Disable `Auto Sync Transforms`** and call `Physics.SyncTransforms()` once per frame
4. **Increase Fixed Timestep** (0.02 to 0.03) if physics load is high and precision is not critical
5. **Use layers** to minimize collision pair checks
6. **Sleep thresholds** — PhysX automatically sleeps idle bodies; don't wake them unnecessarily
7. **Avoid `GetComponent` in collision callbacks** — cache references in `Awake`
