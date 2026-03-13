# Unity Particles and VFX

Reference guide for particle systems and visual effects in Unity. Covers the Shuriken
Particle System, VFX Graph, common effect recipes, and optimization.

## Particle System (Shuriken) Overview

Unity's CPU-based particle system. Each ParticleSystem component has a set of modules
that control emission, movement, appearance, and lifetime.

### Module Overview

| Module | Purpose | Key Properties |
|--------|---------|----------------|
| **Main** | Lifetime, speed, size, gravity, simulation space | Duration, Start Lifetime, Start Speed, Start Size, Gravity Modifier |
| **Emission** | How many particles spawn | Rate Over Time, Rate Over Distance, Bursts |
| **Shape** | Where particles spawn from | Shape type, radius, angle, emit from |
| **Velocity Over Lifetime** | Modify velocity after spawn | Linear/Orbital/Radial velocity curves |
| **Limit Velocity Over Lifetime** | Cap speed, apply drag | Speed, Dampen |
| **Inherit Velocity** | Inherit emitter movement | Mode (Initial/Current), Multiplier |
| **Force Over Lifetime** | Apply forces (wind, gravity) | XYZ force curves |
| **Color Over Lifetime** | Fade in/out, color shift | Gradient |
| **Size Over Lifetime** | Grow/shrink | Curve |
| **Rotation Over Lifetime** | Spin particles | Angular velocity |
| **Noise** | Turbulence, organic motion | Strength, Frequency, Scroll Speed |
| **Collision** | Bounce off surfaces | World/Planes, Bounce, Lifetime Loss |
| **Trigger** | Detect entry/exit from colliders | Inside/Outside/Enter/Exit callbacks |
| **Sub-Emitters** | Spawn child particles | On Birth/Death/Collision/Trigger |
| **Texture Sheet Animation** | Flipbook animation | Grid mode, rows, columns, frame curve |
| **Renderer** | How particles look | Billboard, Stretched, Mesh, Trail, Material |

## Shape Module

Controls where particles originate:

| Shape | Emit From | Use Case |
|-------|-----------|----------|
| Sphere | Volume / Surface / Edge | Explosions, magic orbs |
| Hemisphere | Half sphere | Ground bursts |
| Cone | Base / Volume / Shell | Torch fire, spotlight dust |
| Box | Volume / Surface / Edge | Snow, rain (wide area) |
| Mesh | Vertices / Edges / Triangles | Emitting from a character mesh |
| Circle | Edge / Ring | Ground ring effects |
| Edge | Along a line | Waterfall edge |
| Sprite | Sprite shape | 2D effects |

```
// Fire torch shape:
Shape: Cone
  Angle: 15
  Radius: 0.3
  Emit from: Base
  Randomize Direction: 0.1
```

## Emission Module

### Rate Modes

```
Rate Over Time: 50         // 50 particles per second (continuous)
Rate Over Distance: 10     // 10 particles per unit moved (tire marks, footprints)
```

### Bursts

Emit a batch at a specific time:

```
Bursts:
  Time: 0.0,  Count: 30,  Cycles: 1,  Interval: 0,  Probability: 1.0
  Time: 0.5,  Count: 15,  Cycles: 3,  Interval: 0.2, Probability: 0.8
```

## Sub-Emitters

Child particle systems triggered by parent particle events:

| Trigger | When | Example |
|---------|------|---------|
| Birth | Particle is created | Trail behind each spark |
| Collision | Particle hits a surface | Sparks on impact |
| Death | Particle expires | Smoke puff at end of fire particle |
| Trigger | Particle enters trigger volume | Sizzle in water |

Setup: Add Sub-Emitters module, select trigger type, assign a child ParticleSystem.

```
// Firework setup:
Parent (launch particle):
  Sub-Emitters:
    On Death -> ExplosionPS

ExplosionPS:
  Emission: Burst of 50
  Shape: Sphere
  Sub-Emitters:
    On Death -> SparkPS

SparkPS:
  Emission: Burst of 3
  Start Lifetime: 0.3
  Color Over Lifetime: Yellow -> Red -> Transparent
```

## Collision Module

### World Collision

```
Collision:
  Type: World
  Mode: 3D
  Dampen: 0.2          // Speed reduction on bounce (0-1)
  Bounce: 0.5           // Bounciness (0-1)
  Lifetime Loss: 0.1    // Fraction of remaining lifetime lost per bounce
  Min Kill Speed: 0.5   // Particles slower than this are killed
  Collision Quality: High
  Collides With: Default, Ground  // Layer mask
  Send Collision Messages: true   // Enables OnParticleCollision
```

### Receiving Collision Events

```csharp
public class ParticleCollisionHandler : MonoBehaviour
{
    ParticleSystem _ps;
    List<ParticleCollisionEvent> _collisionEvents = new();

    void Awake() => _ps = GetComponent<ParticleSystem>();

    void OnParticleCollision(GameObject other)
    {
        int count = _ps.GetCollisionEvents(other, _collisionEvents);
        for (int i = 0; i < count; i++)
        {
            Vector3 hitPoint = _collisionEvents[i].intersection;
            Vector3 hitNormal = _collisionEvents[i].normal;
            // Spawn decal, play sound, apply damage, etc.
            SpawnImpactDecal(hitPoint, hitNormal);
        }
    }
}
```

## Texture Sheet Animation

Animate particles using a sprite sheet:

```
Texture Sheet Animation:
  Mode: Grid
  Tiles: 4 x 4              // 16 frames
  Animation: Whole Sheet
  Frame Over Time: Curve (0 to 1 over lifetime)
  Start Frame: Random Between 0 and 3   // Variety
  Cycles: 1
```

Useful for: cartoon smoke puffs, explosions, fire, stylized effects.

## Renderer Module

### Render Modes

| Mode | Behavior | Use For |
|------|----------|---------|
| Billboard | Always faces camera | Most particles (fire, smoke, sparks) |
| Stretched Billboard | Stretches along velocity | Rain, speed lines, tracers |
| Horizontal Billboard | Flat on XZ plane | Ground decals, puddles |
| Vertical Billboard | Faces camera but stays upright | Grass, small foliage |
| Mesh | 3D mesh per particle | Debris, leaves, shrapnel |
| None | Invisible (trail only) | Used with Trail Renderer |

### Stretched Billboard Settings

```
Renderer:
  Render Mode: Stretched Billboard
  Speed Scale: 0.1        // Stretch based on speed
  Length Scale: 1.0        // Base stretch length
  Camera Scale: 0          // Stretch based on camera distance
```

### Trail Renderer

Enable **Trails** module for particles that leave trails:

```
Trails:
  Mode: Particles
  Ratio: 1.0              // Fraction of particles with trails
  Lifetime: 0.5           // Trail duration
  Minimum Vertex Distance: 0.1
  Width Over Trail: Curve (1 to 0)  // Taper off
  Color Over Trail: Gradient
  Inherit Particle Color: true
```

## Particle System API

```csharp
public class ParticleController : MonoBehaviour
{
    [SerializeField] ParticleSystem _ps;

    void Start()
    {
        // Read/modify main module (struct -- must assign back)
        var main = _ps.main;
        main.startColor = Color.red;
        main.startLifetime = 2f;
        main.maxParticles = 500;
        main.simulationSpace = ParticleSystemSimulationSpace.World;

        // Modify emission
        var emission = _ps.emission;
        emission.rateOverTime = 100f;

        // Add a burst
        emission.SetBurst(0, new ParticleSystem.Burst(0f, 50));
    }

    // Playback control
    public void Play() => _ps.Play();
    public void Stop() => _ps.Stop(true, ParticleSystemStopBehavior.StopEmitting);
    public void StopImmediate() => _ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
    public void Pause() => _ps.Pause();

    // Manual emission
    public void EmitBurst(int count)
    {
        var emitParams = new ParticleSystem.EmitParams();
        emitParams.position = transform.position;
        emitParams.startColor = Color.yellow;
        emitParams.startSize = 0.5f;
        _ps.Emit(emitParams, count);
    }

    // Read particle count
    void Update()
    {
        int alive = _ps.particleCount;
        bool isPlaying = _ps.isPlaying;
    }
}
```

## VFX Graph (GPU Particles)

Visual effect authoring tool using a node-based graph. Runs on the GPU via compute shaders.

### Package

```json
"com.unity.visualeffectgraph": "17.0.3"
```

Requires URP or HDRP. Does not work with the Built-in Render Pipeline.

### Architecture

VFX Graph uses four sequential contexts:

| Context | Purpose | Runs |
|---------|---------|------|
| **Spawn** | Controls particle creation rate/bursts | Every frame (CPU) |
| **Initialize** | Set initial properties (position, velocity, color, size) | Per particle, at birth (GPU) |
| **Update** | Modify properties each frame (forces, collisions, aging) | Per particle, every frame (GPU) |
| **Output** | Render particles (mesh, quad, strip, point) | Per particle, every frame (GPU) |

### Creating a VFX Graph

1. **Assets > Create > VFX > Visual Effect Graph**
2. Add a **Visual Effect** component to a GameObject
3. Assign the VFX Graph asset
4. Open the graph in the VFX Graph editor window

### Key Nodes

```
Spawn Context:
  Constant Spawn Rate: 1000
  Periodic Burst: Count 200, Delay 0.5

Initialize Context:
  Set Position (Shape: Sphere, Radius: 2)
  Set Velocity (Direction: Random, Speed: 5)
  Set Lifetime (Random: 1.0 - 2.0)
  Set Size (Random: 0.05 - 0.2)
  Set Color (Gradient Over Lifetime)

Update Context:
  Gravity (Force: -9.81)
  Turbulence (Intensity: 3, Frequency: 2)
  Collision (Plane/Sphere/Mesh)
  Age Particles
  Reap Particles (removes dead)

Output Context:
  Output Particle Quad (Billboard)
  Set Size Over Lifetime
  Set Color Over Lifetime
  Main Texture: particle_soft
```

### Exposed Properties

Expose graph properties to control from code:

```csharp
VisualEffect _vfx;

void Start()
{
    _vfx = GetComponent<VisualEffect>();
    _vfx.SetFloat("SpawnRate", 500f);
    _vfx.SetVector3("EmitterPosition", transform.position);
    _vfx.SetGradient("ColorGradient", myGradient);
    _vfx.SetTexture("MainTexture", myTexture);
}

// Events (trigger spawn bursts)
_vfx.SendEvent("OnHit");
_vfx.SendEvent("OnExplosion");
```

## VFX Graph vs Particle System

| Criteria | Particle System (Shuriken) | VFX Graph |
|----------|---------------------------|-----------|
| Execution | CPU | GPU (compute shaders) |
| Particle Count | Thousands | Millions |
| Render Pipeline | Built-in, URP, HDRP | URP, HDRP only |
| Authoring | Inspector modules | Node graph |
| Collision | Built-in world collision | Simplified (planes, spheres) |
| SubEmitters | Full support | Event-based (different model) |
| Physics Interaction | OnParticleCollision messages | No direct physics callbacks |
| Script Control | Extensive API | Exposed properties + events |

**Use Particle System when:** You need CPU-side collision callbacks, script-driven emission, small-to-medium particle counts, or Built-in Render Pipeline support.

**Use VFX Graph when:** You need massive particle counts (100K+), GPU-driven simulation, complex behaviors via visual programming, or HDRP integration.

## Common Effect Recipes

### Fire

```
Main: Lifetime 0.5-1.0, Speed 1-3, Gravity -0.5 (float up)
Shape: Cone, Angle 15, Radius 0.2
Color Over Lifetime: Yellow (0%) -> Orange (40%) -> Red (70%) -> Black transparent (100%)
Size Over Lifetime: 1.0 -> 1.5 -> 0.0 (grow then shrink)
Noise: Strength 0.5, Frequency 3 (flicker)
Renderer: Billboard, Additive material
```

### Smoke

```
Main: Lifetime 2-4, Speed 0.5-1, Gravity -0.1, Start Size 0.5-1.5
Shape: Cone, Angle 20
Color Over Lifetime: Dark gray 50% alpha -> Light gray 0% alpha
Size Over Lifetime: 0.5 -> 2.0 (expand)
Noise: Strength 1, Frequency 1, Octaves 3 (turbulence)
Rotation Over Lifetime: 30-90 deg/s (tumble)
Renderer: Billboard, Alpha blended material
```

### Dust Trail (Behind Vehicle)

```
Main: Lifetime 1.5-3, Start Size 0.2-0.5, Simulation Space World
Emission: Rate Over Distance 15
Shape: Edge, Radius 0.5
Color Over Lifetime: Tan 80% alpha -> Transparent
Size Over Lifetime: 0.3 -> 2.0
Velocity Over Lifetime: Small upward drift (Y: 0.3)
Noise: Strength 0.3, Frequency 2
```

### Sparks (On Impact)

```
Main: Lifetime 0.3-0.8, Speed 3-8, Gravity 3, Start Size 0.02-0.05
Emission: Burst of 10-30
Shape: Hemisphere, Radius 0.1
Color Over Lifetime: White -> Yellow -> Orange -> Transparent
Size Over Lifetime: 1.0 -> 0.0
Collision: World, Bounce 0.3, Lifetime Loss 0.3
Renderer: Stretched Billboard, Speed Scale 0.2
Trails: Ratio 0.5, Lifetime 0.2, Width Taper
```

### Rain

```
Main: Lifetime 1-2, Speed 15-20, Start Size 0.02-0.04
Emission: Rate Over Time 2000
Shape: Box, Scale (30, 0, 30), position above camera
Color: Light blue-white, 60% alpha
Renderer: Stretched Billboard, Length Scale 2, Speed Scale 0.5
Collision: World (optional), spawn splash sub-emitter on collision
```

### Explosion

```
// Core flash
Main: Lifetime 0.1, Speed 0, Start Size 3
Emission: Burst 1
Color: White -> Orange -> Transparent
Renderer: Billboard, Additive

// Debris
Main: Lifetime 1-2, Speed 5-15, Gravity 5, Start Size 0.1-0.3
Emission: Burst 20-40
Shape: Sphere, Radius 0.5
Collision: World, Bounce 0.4
Renderer: Mesh (rock/debris mesh), Random rotation

// Smoke cloud (delayed)
Main: Start Delay 0.1, Lifetime 2-4, Speed 1-2, Start Size 1-3
Emission: Burst 10-15
Shape: Sphere, Radius 1
Color Over Lifetime: Dark gray -> Transparent
Size Over Lifetime: Grow
```

## Optimization

### Key Settings

| Setting | Impact | Recommendation |
|---------|--------|----------------|
| Max Particles | Memory + overdraw | Set to the minimum you actually need |
| Simulation Space | CPU cost | World for persistent, Local for attached |
| Collision Quality | CPU (major) | Use Medium or Low for non-critical effects |
| Culling | GPU | Enable on Renderer: Automatic or custom bounds |
| GPU Instancing | Draw calls | Enable on Renderer for mesh particles |
| Ring Buffer | Memory | Enable for effects where oldest particles should be recycled |

### LOD for Particles

```csharp
// Reduce particle count based on distance
public class ParticleLOD : MonoBehaviour
{
    [SerializeField] ParticleSystem _ps;
    [SerializeField] float _fullDetailDistance = 20f;
    [SerializeField] float _cullDistance = 80f;
    [SerializeField] float _maxEmission = 100f;

    Transform _camera;
    ParticleSystem.EmissionModule _emission;

    void Start()
    {
        _camera = Camera.main.transform;
        _emission = _ps.emission;
    }

    void Update()
    {
        float dist = Vector3.Distance(transform.position, _camera.position);
        if (dist > _cullDistance)
        {
            if (_ps.isPlaying) _ps.Stop();
            return;
        }

        if (!_ps.isPlaying) _ps.Play();
        float t = Mathf.InverseLerp(_fullDetailDistance, _cullDistance, dist);
        _emission.rateOverTime = Mathf.Lerp(_maxEmission, _maxEmission * 0.1f, t);
    }
}
```

### Overdraw Reduction

- Use **smaller particles** with higher emission rates rather than fewer large particles
- Use **alpha cutoff** materials instead of alpha blend where possible
- Limit **overlapping transparent particles** in the same screen area
- Use the **Scene View Overdraw mode** to identify hotspots
