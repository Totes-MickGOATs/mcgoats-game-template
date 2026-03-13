# Unity 3D Materials and Shaders

Comprehensive guide to materials, textures, and shader configuration in Unity.

## Material Fundamentals

A Material is a Shader + a set of property values. The shader defines what properties exist; the material stores the values.

### Creating Materials

```
Assets > Create > Material
  - Assign a shader (default: URP/Lit or HDRP/Lit)
  - Set texture maps, colors, numeric values
  - Drag onto objects or assign via Mesh Renderer
```

### Material Instances vs Shared Materials

```csharp
// Shared material — editing affects ALL objects using this material
// Use renderer.sharedMaterial for read-only access or intentional global changes
Material shared = renderer.sharedMaterial;

// Instance material — Unity auto-clones when you access .material
// Creates a unique copy for THIS renderer only
// WARNING: creates a new material instance (memory leak if not managed)
Material instance = renderer.material;
instance.color = Color.red;  // Only affects this object

// Cleanup instanced materials
void OnDestroy()
{
    if (renderer.material != null)
        Destroy(renderer.material);
}
```

### Assigning Materials in Code

```csharp
// Single material
renderer.material = newMaterial;

// Multiple materials (sub-meshes)
Material[] mats = renderer.materials;  // Returns copies!
mats[1] = newMaterial;
renderer.materials = mats;

// Shared (no copy)
renderer.sharedMaterial = newMaterial;
```

## URP Lit Shader

The standard PBR shader for Universal Render Pipeline.

### Texture Maps

| Map | Property | Purpose |
|-----|----------|---------|
| Base Map | `_BaseMap` | Albedo/diffuse color + alpha |
| Normal Map | `_BumpMap` | Surface detail via tangent-space normals |
| Metallic Map | `_MetallicGlossMap` | R = metallic, A = smoothness |
| Occlusion Map | `_OcclusionMap` | Baked ambient occlusion (R channel) |
| Emission Map | `_EmissionMap` | Self-illumination color and intensity |
| Detail Map | `_DetailMap` | Tiling detail overlay (albedo + normal) |

### Setting Properties in Code

```csharp
Material mat = renderer.material;

// Color and texture
mat.SetColor("_BaseColor", new Color(0.8f, 0.2f, 0.2f, 1f));
mat.SetTexture("_BaseMap", albedoTexture);

// Metallic-smoothness
mat.SetFloat("_Metallic", 0.9f);
mat.SetFloat("_Smoothness", 0.7f);

// Normal map
mat.SetTexture("_BumpMap", normalTexture);
mat.SetFloat("_BumpScale", 1.5f);  // Normal intensity

// Emission
mat.EnableKeyword("_EMISSION");
mat.SetColor("_EmissionColor", Color.cyan * 3f);
mat.SetTexture("_EmissionMap", emissionTexture);

// Tiling and offset
mat.SetTextureScale("_BaseMap", new Vector2(2f, 2f));
mat.SetTextureOffset("_BaseMap", new Vector2(0.5f, 0f));
```

### Surface Options

```
Surface Type:
  - Opaque — default, no transparency
  - Transparent — alpha blending (see-through)

Render Face:
  - Front — default, backface culling
  - Back — render inside only
  - Both — double-sided (foliage, cloth)

Alpha Clipping:
  - Enable for cutout transparency (leaves, fences)
  - Threshold: alpha value below which pixels are discarded
```

## HDRP Lit Shader

Extended PBR features beyond URP.

### Additional Features

| Feature | Purpose |
|---------|---------|
| Subsurface Scattering | Light passing through translucent materials (skin, wax, leaves) |
| Translucency | Back-lit thin surfaces (ears, curtains) |
| Coat Mask | Clear-coat layer (car paint, lacquered wood) |
| Anisotropy | Direction-dependent reflections (brushed metal, hair) |
| Iridescence | Color shift based on viewing angle (soap bubbles, oil) |
| Detail Map | Micro-surface detail at close range |

### HDRP Material Types

```
Lit — standard PBR (most objects)
Unlit — no lighting, flat color (UI elements, custom lighting)
Decal — projected surface detail
Fabric — cotton, silk, velvet (custom shading model)
Hair — strand-based anisotropic shading
Eye — specialized eye rendering with caustics
StackLit — advanced layered materials (coat + base)
```

## Shader Graph

Visual shader authoring for URP and HDRP.

### Creating a Shader Graph

```
Assets > Create > Shader Graph > URP > Lit Shader Graph
  - Opens visual node editor
  - Connect nodes from left to right
  - Output to Master Stack (Vertex and Fragment stages)
```

### Master Stack Outputs

**Fragment stage (pixel-level):**

| Output | Type | Purpose |
|--------|------|---------|
| Base Color | Color (RGB) | Surface albedo |
| Normal (Tangent Space) | Vector3 | Per-pixel normal perturbation |
| Metallic | Float | 0 = dielectric, 1 = metal |
| Smoothness | Float | 0 = rough, 1 = mirror |
| Emission | Color (RGB) | Self-illumination |
| Ambient Occlusion | Float | Cavity darkening |
| Alpha | Float | Transparency |

**Vertex stage (vertex-level):**

| Output | Type | Purpose |
|--------|------|---------|
| Position | Vector3 | Vertex displacement (wind, waves) |
| Normal | Vector3 | Modified vertex normal |
| Tangent | Vector3 | Modified vertex tangent |

### Common Node Patterns

```
Time-based animation:
  Time node → Multiply (speed) → Add (UV) → Sample Texture 2D

Fresnel/rim lighting:
  Fresnel Effect node → Multiply (color) → Add to Emission

World-space triplanar:
  Position (World) → Triplanar node → Base Color

Dissolve effect:
  Sample Noise → Step (threshold) → Alpha + Emission at edge
```

### Sub-Graphs

Reusable shader modules. Create via **Assets > Create > Shader Graph > Sub Graph**.

```
Use for:
  - Shared noise functions across multiple shaders
  - UV manipulation utilities
  - Common blending operations
  - Team-standardized patterns
```

### Custom Function Nodes

Write HLSL code callable from Shader Graph:

```hlsl
// MyCustomFunction.hlsl
void MyBlend_float(float3 A, float3 B, float T, out float3 Out)
{
    Out = lerp(A, B, saturate(T));
}
```

In Shader Graph: Add **Custom Function** node, set Source to File, reference `.hlsl` file.

## Material Property Blocks

Per-renderer overrides without creating new material instances. GPU instancing friendly.

```csharp
// Ideal for: changing color per instance while keeping batching
private MaterialPropertyBlock _propBlock;
private Renderer _renderer;

void Awake()
{
    _propBlock = new MaterialPropertyBlock();
    _renderer = GetComponent<Renderer>();
}

void SetColor(Color color)
{
    _renderer.GetPropertyBlock(_propBlock);
    _propBlock.SetColor("_BaseColor", color);
    _renderer.SetPropertyBlock(_propBlock);
}

void SetDamageAmount(float damage)
{
    _renderer.GetPropertyBlock(_propBlock);
    _propBlock.SetFloat("_DamageAmount", damage);
    _renderer.SetPropertyBlock(_propBlock);
}
```

**When to use PropertyBlock vs material instance:**

| Scenario | Use |
|----------|-----|
| Unique color per unit (1000 soldiers) | PropertyBlock |
| Fundamentally different shader settings | Material instance |
| Animating a property per object | PropertyBlock |
| Changing textures per object | Material instance (breaks batching anyway) |
| GPU instancing with variation | PropertyBlock (required) |

## Texture Setup

### Import Settings

| Setting | Purpose | Recommended |
|---------|---------|-------------|
| Texture Type | Normal Map, Default, Sprite, etc. | Match usage |
| sRGB | Color space | ON for albedo/emission, OFF for data (normal, metallic) |
| Max Size | Resolution limit | 2048 for hero assets, 512-1024 for props |
| Compression | Quality vs size | Normal Quality for most, High for hero |
| Generate Mip Maps | LOD for textures | ON for 3D, OFF for UI/sprites |
| Filter Mode | Sampling | Bilinear (default), Trilinear (mipmaps), Point (pixel art) |
| Wrap Mode | Edge behavior | Repeat (tiling), Clamp (UI/skybox) |

### Compression Formats

| Platform | Format | Notes |
|----------|--------|-------|
| Desktop | BC7 (DXT5 fallback) | Best quality-to-size ratio |
| Android | ASTC 6x6 | Good balance; ETC2 as fallback |
| iOS | ASTC 6x6 | Standard for modern iOS |
| Normal Maps | BC5 (desktop), ASTC | 2-channel compression, better quality |

### Normal Map Encoding

```
Unity default: tangent-space, OpenGL Y+ (green up)
  - If importing DirectX normals (green down): check "Flip Green Channel" in import settings
  - Texture Type MUST be set to "Normal map" for correct compression and sRGB handling
```

## PBR Workflow

### Metallic Workflow (Unity Default)

```
Base Color (RGB): albedo — the color of the surface
  - Metals: reflectance color (gold = yellow, copper = orange)
  - Non-metals: diffuse color (plastic, wood, fabric)

Metallic (Float 0-1):
  - 0: dielectric (non-metal) — most things
  - 1: conductor (metal) — pure metals only
  - In-between: rare (dirty/painted metal)

Smoothness (Float 0-1):
  - 0: completely rough (concrete, chalk)
  - 1: perfectly smooth (mirror, chrome)
```

### Specular Workflow (Alternative)

```
Use "Lit (Specular)" shader variant.
  - Specular Color (RGB): replaces Metallic
  - More control for non-standard materials
  - Most teams prefer Metallic workflow (simpler)
```

### Texture Authoring Guidelines

```
Albedo:
  - NO lighting information (no shadows, no highlights)
  - Consistent brightness (50-240 sRGB range)
  - Pure white and pure black are physically impossible

Normal Map:
  - Encode surface detail, not shape (that's geometry)
  - Flat = (128, 128, 255) in tangent space
  - Use Substance/xNormal/Marmoset for baking

Metallic/Smoothness:
  - Pack into one texture: RGB = metallic, A = smoothness
  - Most surfaces are 0 or 1 metallic (no gradients)
  - Smoothness varies widely (fingerprints, wear, dirt)

Ambient Occlusion:
  - Baked cavity shadows (crevices, folds)
  - Grayscale: white = fully lit, black = fully occluded
  - Do NOT bake directional shadows (only ambient)
```

## Material Variants (Unity 2022+)

Parent-child material relationships. Change the parent; children inherit unless overridden.

```
Create: right-click material > Create > Material Variant
  - Override individual properties
  - Non-overridden properties track the parent
  - Useful for: color variations of the same base material
  - Example: BaseWood → DarkWood, LightWood, WetWood
```

```csharp
// Check if property is overridden
bool isOverridden = material.IsPropertyOverriden("_BaseColor"); // Note Unity API typo

// Reset override (revert to parent value)
material.RevertPropertyOverride("_BaseColor");
```

## Shader Keywords and Variants

### multi_compile vs shader_feature

```hlsl
// multi_compile — ALL combinations compiled, always available
#pragma multi_compile _ _RAIN_ON

// shader_feature — only combinations used by materials in build are compiled
// Unused variants are stripped — smaller build, but runtime enabling may fail
#pragma shader_feature _DETAIL_ON

// Rule of thumb:
// - shader_feature for material-driven toggles (artist sets in Inspector)
// - multi_compile for runtime/global toggles (code enables/disables)
```

### Enabling Keywords at Runtime

```csharp
// Global (affects all shaders)
Shader.EnableKeyword("_RAIN_ON");
Shader.DisableKeyword("_RAIN_ON");

// Per-material
material.EnableKeyword("_DETAIL_ON");
material.DisableKeyword("_DETAIL_ON");
```

### Variant Stripping

```
Too many keywords = combinatorial explosion of shader variants.
  - Each keyword doubles variant count
  - 10 keywords = 1024 variants per shader (most unused)

Solutions:
  - Use shader_feature (strips unused at build time)
  - Implement IPreprocessShaders to strip manually
  - Keep keywords under 10 per shader
  - Use local keywords (#pragma shader_feature_local) to avoid global limit
```

## Common Material Patterns

### Terrain Splatmapping

```
4 terrain layers blended via control map (RGBA = weights):
  - Each layer: albedo + normal + mask (metallic/AO/smoothness)
  - Unity Terrain handles this automatically with Terrain Layers
  - Custom: sample control map, lerp between 4 textures by weight
```

### Vertex Color Blending

```csharp
// Paint vertex colors in Polybrush or DCC tool
// Shader reads vertex color to blend textures
// R = snow amount, G = moss, B = dirt (example)

// In Shader Graph:
// Vertex Color node → Split → use channels as lerp factors
```

### Triplanar Mapping

```
Projects textures from 3 axes (X, Y, Z) based on surface normal.
  - Eliminates UV stretching on cliffs/overhangs
  - 3x texture samples — use for terrain/rocks, not everything
  - In Shader Graph: Triplanar node (built-in)
```

### Dissolve Effect

```
Shader Graph approach:
  1. Sample noise texture (Simplex, Voronoi)
  2. Compare noise value to _DissolveAmount threshold
  3. Clip pixels below threshold (Alpha Clip)
  4. Add emission at dissolve edge (Step + narrow band)
  5. Animate _DissolveAmount from 0 to 1 over time
```

## Performance

### Batching Rules

```
Static Batching:
  - Combines static meshes sharing the same material
  - Mark as Batching Static in Inspector
  - One draw call per unique material

Dynamic Batching:
  - Automatic for small meshes (< 300 vertices with position+normal+UV)
  - Same material required
  - Usually not worth relying on — SRP Batcher is better

SRP Batcher (URP/HDRP):
  - Groups draw calls by shader (not material)
  - Materials using the same shader batch even with different properties
  - Enabled in URP/HDRP Asset settings
  - Shader must be SRP Batcher compatible (use CBUFFER macros)
```

### GPU Instancing

```csharp
// Enable on material: material.enableInstancing = true
// Or check "Enable GPU Instancing" in material Inspector
// Combined with MaterialPropertyBlock for per-instance variation
// All instances must share the same mesh and material
```

### Texture Atlasing

```
Combine multiple textures into one atlas:
  - Reduces material count → more batching
  - UV mapping points to atlas sub-regions
  - Tools: Texture Packer, Unity Sprite Atlas (2D), custom atlas builder
```

### LOD Material Swaps

```
LOD Group with simpler materials at distance:
  - LOD0: full PBR (normal, detail, emission)
  - LOD1: simplified (no detail map, lower-res textures)
  - LOD2: unlit or vertex-lit single color
  - Reduces shader complexity and texture bandwidth at distance
```

## Material Debugging

```csharp
// List all properties on a material
Shader shader = material.shader;
int count = shader.GetPropertyCount();
for (int i = 0; i < count; i++)
{
    string name = shader.GetPropertyName(i);
    ShaderPropertyType type = shader.GetPropertyType(i);
    Debug.Log($"{name}: {type}");
}

// Check enabled keywords
foreach (string keyword in material.enabledKeywords)
    Debug.Log($"Keyword: {keyword}");
```

### Frame Debugger

```
Window > Analysis > Frame Debugger
  - Step through every draw call
  - See which material/shader is used
  - Identify batching breaks (different material = new batch)
  - Check shader properties per draw call
```
