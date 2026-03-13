# Unity 3D Lighting

Comprehensive guide to lighting in Unity across URP and HDRP render pipelines.

## Light Types

### Directional Light

Simulates distant light (sun/moon). Affects the entire scene uniformly.

```
- No position falloff — only rotation matters
- One directional light is "free" in forward rendering
- Additional directional lights are expensive
- Controls shadow cascades
```

### Point Light

Emits in all directions from a position. Falloff by distance.

```
- Good for: lamps, torches, explosions, fireflies
- Shadow maps require 6 faces (cubemap) — expensive
- URP: limited number of per-object additional lights
```

### Spot Light

Cone-shaped emission. Position + direction + angle.

```
- Good for: flashlights, stage lights, car headlights
- Inner/outer angle controls falloff softness
- Single shadow map face — cheaper than point light shadows
```

### Area Light

Rectangular or disc-shaped emitter. Soft, realistic shadows.

```
- URP: baked only (no realtime area lights)
- HDRP: realtime area lights supported (rect, disc, tube)
- Most physically accurate light type
- Expensive — use sparingly for realtime
```

## Realtime vs Mixed vs Baked

### Realtime Lighting

```
Pros:
  - Dynamic — moves, changes color/intensity at runtime
  - No bake time, instant iteration
  - Shadows update every frame
Cons:
  - Most expensive at runtime
  - No global illumination (light bounces)
  - Shadow quality limited by resolution budget
Use for: player flashlight, moving sun, dynamic effects
```

### Baked Lighting

```
Pros:
  - Zero runtime cost for light calculation
  - Includes global illumination (light bounces, color bleeding)
  - Soft, high-quality shadows
Cons:
  - Static only — cannot move lights or shadow casters
  - Long bake times for large scenes
  - Lightmap memory (textures stored on disk)
Use for: architectural visualization, static environments, mobile games
```

### Mixed Lighting

```
Modes (set per-light):
  - Baked Indirect: Direct light is realtime, indirect (bounced) is baked
  - Shadowmask: Baked shadows for static objects, realtime for dynamic
  - Subtractive: Everything baked, one directional light for dynamic shadows

Best balance for most games: Baked Indirect or Shadowmask
```

### Setting Light Mode

```csharp
// In Inspector: Light component > Mode dropdown
// Or via script:
Light light = GetComponent<Light>();
light.lightmapBakeType = LightmapBakeType.Mixed;
```

## URP Lighting Specifics

### Additional Lights Limit

```
URP Asset > Lighting:
  - Main Light: single directional (sun)
  - Additional Lights:
    - Per Vertex: cheapest, low quality
    - Per Pixel: better quality, limited count
    - Max Additional Lights: default 4 (mobile) or 8 (desktop)
```

### Forward+ Rendering (Unity 2022.2+)

```
URP Asset > Rendering > Rendering Path: Forward+
  - Removes per-object light limit
  - Cluster-based light culling (similar to deferred)
  - Hundreds of lights possible with good performance
  - Recommended for desktop/console with many lights
```

### URP Light Configuration

```csharp
// Access URP additional light data
var additionalData = light.GetComponent<UniversalAdditionalLightData>();
additionalData.usePipelineSettings = false;  // Override pipeline defaults
```

## HDRP Lighting Specifics

### Physical Light Units

HDRP uses real-world light measurements:

| Unit | Used By | Example Values |
|------|---------|---------------|
| Lux | Directional | 120,000 (noon sun), 400 (overcast) |
| Lumen | Point, Spot | 800 (60W bulb), 12,000 (streetlight) |
| Candela | Spot | Luminous intensity in a direction |
| Nits | Area | 1,500 (fluorescent panel) |
| EV | Exposure | 14.5 (sunny day), 8 (interior) |

### Volumetric Fog

```
HDRP exclusive feature:
  - Fog Volume component with Density Volume
  - Lights contribute to fog scattering
  - Configurable: scattering, extinction, anisotropy
  - Performance: controlled by volumetric fog quality in HDRP Asset
```

### HDRP Area Lights (Realtime)

```
Supported shapes: Rectangle, Disc, Tube
  - Soft shadows with area shape
  - Screen-space shadow option for performance
  - Emission mesh visualization
```

## Light Probes

Light Probes capture baked lighting at points in space for dynamic objects.

### Placement Strategy

```
- Place probes in a 3D grid throughout the playable area
- Denser near lighting transitions (shadow edges, color changes)
- Inside and outside doorways/windows
- At different heights for multi-floor areas
- Avoid placing inside geometry (invalid data)
```

### Light Probe Group

```csharp
// Add via Component > Rendering > Light Probe Group
// Edit in Scene view: select group, use editing tools

// Dynamic objects automatically sample nearby probes
// Ensure Mesh Renderer > Light Probes = Blend Probes
renderer.lightProbeUsage = LightProbeUsage.BlendProbes;

// For large objects that span multiple probes:
renderer.lightProbeUsage = LightProbeUsage.UseProxyVolume;
// Add Light Probe Proxy Volume component
```

### Scripted Probe Sampling

```csharp
// Sample probes at a specific position
SphericalHarmonicsL2 sh;
LightProbes.GetInterpolatedProbe(worldPosition, null, out sh);

// Apply to a material
MaterialPropertyBlock props = new MaterialPropertyBlock();
renderer.GetPropertyBlock(props);
// SH data is automatically applied to renderers using probes
```

## Reflection Probes

Capture the environment for reflective surfaces (metals, water, glass).

### Types

```
Baked:
  - Captured once at bake time
  - Zero runtime cost
  - Cannot reflect dynamic objects

Realtime:
  - Re-renders cubemap at runtime
  - Can reflect dynamic objects
  - Very expensive — limit to 1-2 per scene
  - Set refresh mode: On Awake, Every Frame, or Via Scripting

Custom:
  - User-supplied cubemap texture
  - Zero cost, full control
```

### Projection Modes

```
Standard (infinite):
  - Default, no parallax correction
  - Good for outdoor open areas

Box Projection:
  - Parallax-corrected reflections
  - Accurate for interior rooms
  - Set Bounds to match room dimensions
  - Enable: Reflection Probe > Box Projection checkbox
```

### Blending

```
Overlapping probes blend automatically based on renderer position.
  - Mesh Renderer > Reflection Probes: Blend Probes / Simple
  - URP: max 2 probes blended per object
  - Weight falloff based on probe bounds
```

## Lightmapping

### Setup

1. Mark static objects: **GameObject > Static > Contribute GI** (or just Static)
2. Set light mode to Baked or Mixed
3. Open **Window > Rendering > Lighting**
4. Configure and click **Generate Lighting**

### Key Settings

| Setting | Recommended | Notes |
|---------|-------------|-------|
| Lightmap Resolution | 20-40 texels/unit | Higher = better quality, longer bake, more memory |
| Max Lightmap Size | 1024-2048 | Larger = fewer lightmaps, more VRAM per map |
| Lightmapper | Progressive GPU | Much faster than CPU, nearly identical quality |
| Direct Samples | 32 | Increase to reduce noise in direct lighting |
| Indirect Samples | 512 | Increase to reduce noise in bounced lighting |
| Bounces | 2-3 | More bounces = more realistic, diminishing returns past 3 |
| Compress Lightmaps | true | Halves memory, slight quality loss |

### UV Charts

Objects need lightmap UVs. Unity auto-generates them, but you can control quality:

```
Mesh Import Settings > Generate Lightmap UVs: true
  - Pack Margin: 4-8 (texels between UV islands)
  - Angle Error: 8% (UV distortion tolerance)
  - Area Error: 15% (area distortion tolerance)
```

For best results, create lightmap UVs in your DCC tool (Blender, Maya) with no overlaps.

## Global Illumination

### Baked GI

```
Lighting window > Mixed Lighting:
  - Baked Global Illumination: enabled
  - Lighting Mode: Baked Indirect (recommended)

Bounced light is computed during bake and stored in lightmaps.
Dynamic objects receive bounced light via Light Probes.
```

### Enlighten Realtime GI (Legacy)

```
Deprecated in Unity 2024+. Do not use for new projects.
Was: runtime-updated indirect lighting that responded to moving lights.
Replace with: baked GI + Light Probes, or HDRP with Screen Space GI.
```

## Shadow Settings

### Cascade Shadows (Directional Light)

```
URP Asset > Lighting > Main Light:
  - Shadow Resolution: 1024-4096 per cascade
  - Cascade Count: 2 (mobile), 4 (desktop)
  - Shadow Distance: 50-150m (balance quality vs coverage)
  - Last Border: 0.1 (fade out at max distance)

Cascade splits control quality distribution:
  - Front-loaded: better near-camera quality (default, recommended)
  - Even: uniform quality at all distances
```

### Shadow Bias

```
Depth Bias: pushes shadow map away from surface
  - Too low: shadow acne (self-shadowing artifacts)
  - Too high: peter-panning (shadows detach from objects)
  - Start at 1.0, adjust per-light

Normal Bias: pushes along surface normal
  - Helps with thin geometry shadow artifacts
  - Start at 1.0
```

### Per-Light Shadow Settings

```csharp
Light light = GetComponent<Light>();
light.shadows = LightShadows.Soft;      // None, Hard, Soft
light.shadowResolution = LightShadowResolution.High;
light.shadowBias = 0.05f;
light.shadowNormalBias = 0.4f;
light.shadowNearPlane = 0.2f;
```

## Environment Lighting

### Skybox

```
Lighting window > Environment:
  - Source: Skybox
  - Assign a Skybox material (Procedural, Cubemap, Panoramic, or 6-sided)
  - Intensity Multiplier: scales ambient contribution

// Runtime skybox change
RenderSettings.skybox = newSkyboxMaterial;
DynamicGI.UpdateEnvironment();  // Re-evaluate ambient lighting
```

### Gradient / Color

```
Simpler than skybox, no texture required:
  - Gradient: separate sky/equator/ground colors
  - Color: single flat ambient color
```

## Emissive Materials

Materials with emission can contribute to baked GI:

```csharp
// Enable emission on material
material.EnableKeyword("_EMISSION");
material.SetColor("_EmissionColor", Color.yellow * 5f);

// Mark object as static for GI contribution
// In Inspector: Static > Contribute GI
// Emission will bake into nearby lightmaps
```

Set **Emission > Global Illumination** to **Baked** on the material for it to affect lightmaps.

## Post-Processing (Volume System)

URP and HDRP use the Volume framework for post-processing.

### Setup

```
1. Create empty GameObject
2. Add Volume component
3. Set Mode: Global (affects entire scene) or Local (with collider trigger)
4. Create new Volume Profile (or assign existing)
5. Add Override: choose effect
```

### Common Effects

```csharp
// Bloom — glow on bright areas
Bloom bloom;
volume.profile.TryGet(out bloom);
bloom.threshold.value = 1.0f;
bloom.intensity.value = 0.5f;
bloom.scatter.value = 0.7f;

// Color Grading (Tonemapping)
ColorAdjustments colorAdj;
volume.profile.TryGet(out colorAdj);
colorAdj.postExposure.value = 0.5f;
colorAdj.contrast.value = 10f;
colorAdj.saturation.value = 10f;

// SSAO (Screen Space Ambient Occlusion) — URP via Renderer Feature
// HDRP: built-in override in Volume

// SSR (Screen Space Reflections) — HDRP only via Volume override
```

### Volume Blending

```
Multiple volumes can overlap and blend:
  - Weight: 0-1, controls influence
  - Priority: higher priority overrides lower
  - Blend Distance (Local volumes): gradual transition zone

Use Case: enter a cave → local volume darkens exposure, adds fog
```

## Lighting Recipes

### Outdoor Daytime

```
1. Single Directional Light (Mixed, Baked Indirect)
   - Rotation: (50, -30, 0) for classic sun angle
   - Color: warm white (color temperature ~6500K)
   - Intensity: 1.0-2.0

2. Skybox: procedural or HDRI
3. Environment Lighting: Skybox source
4. Baked GI with Light Probes for dynamic objects
5. Cascaded shadows: 4 cascades, 150m distance
```

### Indoor Scene

```
1. Mixed lighting for main lights (ceiling fixtures)
2. Baked GI for light bouncing off walls
3. Light Probes: dense grid, especially near doors/windows
4. Reflection Probes: one per room, box projection
5. Area lights (baked) for soft window light
6. Post-processing: slight bloom, SSAO for depth
```

### Night Scene

```
1. Directional light at very low intensity (moonlight, blue tint)
2. Point/spot lights as key lighting (warm, high contrast)
3. Emissive materials for neon signs, windows
4. Volumetric fog (HDRP) or particle fog (URP)
5. Post-processing: high bloom, vignette, low exposure
```

## Performance Tips

1. **Limit realtime shadow-casting lights** — 1 directional + 2-3 additional max
2. **Bake everything you can** — baked lighting is free at runtime
3. **Use Light Probe Proxy Volumes** for large dynamic objects instead of single probe sampling
4. **Shadow distance** is the single biggest shadow performance lever — keep it as low as acceptable
5. **Reduce shadow resolution** on less important lights
6. **Disable shadows on small/distant lights** — `light.shadows = LightShadows.None`
7. **Forward+** (URP 2022.2+) if you need many lights without deferred rendering
8. **Lightmap compression** halves VRAM usage with minimal visual impact
9. **Avoid overlapping realtime Reflection Probes** — each one re-renders the scene
10. **Use LOD Groups** to reduce triangle count for shadow map rendering at distance
