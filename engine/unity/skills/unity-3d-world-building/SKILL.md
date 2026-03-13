# Unity 3D World Building

Tools, workflows, and patterns for building 3D game environments in Unity.

## Unity Terrain

### Creating Terrain

```
GameObject > 3D Object > Terrain
  - Creates Terrain GameObject with Terrain + Terrain Collider components
  - Default size: 1000x1000 meters (adjust in Terrain Settings)
```

### Heightmap

```
Terrain Settings:
  - Terrain Width/Length: world size in meters
  - Terrain Height: max elevation
  - Heightmap Resolution: 513, 1025, 2049, or 4097
    (power of 2 + 1 — higher = more detail, more memory)

Sculpting tools:
  - Raise/Lower: left-click raise, shift+click lower
  - Set Height: flatten to specific elevation
  - Smooth: average out bumps
  - Stamp: apply height pattern from texture

Import raw heightmap:
  - Terrain Settings > Import Raw
  - Format: RAW 16-bit, byte order: Windows (little-endian)
  - Resolution must match heightmap pixel dimensions
```

### Terrain Layers (Texture Painting)

```
Each terrain layer defines a surface material:
  - Albedo + Normal + Mask (metallic/AO/height/smoothness packed)
  - Tiling Size: how large the texture appears on terrain
  - Tiling Offset: shift texture origin

Adding layers:
  1. Select Terrain > Paint Texture tool
  2. Edit Terrain Layers > Create Layer
  3. Assign textures, set tiling
  4. Paint in Scene view (brush size, opacity, target strength)

Limit: 4 layers per pass without performance penalty.
Each additional set of 4 = another draw pass.
```

### Trees and Details

```
Trees:
  - Terrain > Paint Trees > Edit Trees > Add Tree
  - Assign tree prefab (must have LOD Group for performance)
  - Billboard at distance (auto-generated)
  - Parameters: density, height variation, width variation, color variation

Details (grass, flowers, rocks):
  - Terrain > Paint Details > Edit Details
  - Detail Mesh: 3D mesh instances on terrain
  - Detail Texture: billboarded grass/flower quads
  - Draw Distance: how far details render (50-200m typical)
```

### Terrain Performance

| Setting | Location | Effect |
|---------|----------|--------|
| Pixel Error | Terrain Settings | LOD aggressiveness. Higher = lower quality, better performance. Default 5, try 10-20 for mobile |
| Base Map Distance | Terrain Settings | Distance where terrain switches to low-res composite. 500-1000m for open worlds |
| Draw Instanced | Terrain Settings | GPU instancing for terrain rendering. Always enable |
| Detail Distance | Terrain Settings | Grass/detail render range |
| Detail Density | Terrain Settings | Grass density multiplier |
| Tree Distance | Terrain Settings | Tree render distance |
| Billboard Start | Terrain Settings | Distance where trees become billboards |
| Terrain Holes | Terrain component | Enable to carve holes (caves, tunnels) — slight overhead |

### Multi-Terrain (Large Worlds)

```
For worlds larger than one terrain:
  - Create NxN grid of Terrain tiles
  - Each tile: own heightmap, splatmap, trees
  - Use Terrain Groups for LOD coherence
  - Tools: Unity Terrain Tools package, World Creator, Gaia
```

## ProBuilder

Quick mesh prototyping directly in Unity. Install from Package Manager.

### Core Workflow

```
1. Tools > ProBuilder > ProBuilder Window
2. Create shape: New Shape (cube, cylinder, stairs, arch, etc.)
3. Edit in modes:
   - Object mode: move/rotate/scale whole mesh
   - Vertex mode: move individual vertices
   - Edge mode: select/move edges, insert edge loops
   - Face mode: select/extrude/inset faces
4. UV editing: Auto UV or Manual UV in ProBuilder UV Editor
5. Material assignment: per-face material slots
```

### Common Operations

```
Extrude: select face → Shift+drag or Extrude button
  - Creates new geometry extending from selected face

Inset: select face → Inset
  - Creates smaller face inside, with connecting faces

Boolean: merge two ProBuilder meshes (union, subtract, intersect)
  - Experimental, may need cleanup

Merge: combine multiple ProBuilder objects into one mesh

Detach: separate selected faces into a new object

Subdivide: split selected faces into smaller faces
```

### From Prototype to Final Art

```
1. Block out level with ProBuilder (gray boxes)
2. Playtest and iterate on layout
3. Export to FBX: ProBuilder > Export Mesh
4. Replace with final art meshes (maintain collider shapes)
5. Or: keep ProBuilder meshes with proper materials for simple geometry
```

## Prefab Workflows

### Prefab Basics

```
Create: drag GameObject from Hierarchy to Project window
  - Creates .prefab asset
  - Instances in scene are linked to the prefab
  - Blue text in Hierarchy = prefab instance

Edit:
  - Double-click prefab asset → Prefab Mode (isolated editing)
  - Or select instance → Inspector > Overrides > Open Prefab

Apply/Revert overrides:
  - Instance changes appear as bold properties
  - Apply: push instance changes back to prefab
  - Revert: discard instance changes
```

### Nested Prefabs

```
Prefabs containing other prefab instances:
  Building (prefab)
    ├── Wall (prefab)
    ├── Door (prefab)
    └── Window (prefab)

Changes to Door prefab automatically propagate to all Buildings.
Override specific instances as needed.
```

### Prefab Variants

```
Create: right-click prefab > Create > Prefab Variant
  - Inherits everything from base prefab
  - Override specific properties
  - Base changes propagate to variant (unless overridden)

Example:
  EnemyBase (prefab) → EnemyFast (variant, speed override)
                      → EnemyTank (variant, health override)
```

### Prefab Best Practices

```
- Root object should have the main script component
- Keep transform at origin (0,0,0) in prefab mode
- Use prefab variants for color/size/behavior variations
- Don't nest too deeply (3 levels max for sanity)
- Unpack prefab instance if you need to break the link permanently
```

## LOD Groups

Level of Detail system for rendering simpler meshes at distance.

### Setup

```
1. Add LOD Group component to parent GameObject
2. Child objects assigned to LOD levels:
   - LOD 0: full detail (closest to camera)
   - LOD 1: reduced detail
   - LOD 2: low detail
   - Culled: invisible (beyond max distance)

3. Set transition percentages in LOD Group Inspector
   - Percentage = screen height occupied by object
   - LOD 0: 60%+, LOD 1: 30-60%, LOD 2: 10-30%, Culled: <10%
```

### Cross-Fade

```
Fade Mode:
  - None: hard switch (pop)
  - Cross Fade: smooth blend between LODs
  - Speed Tree: specialized for SpeedTree assets

Fade Transition Width: 0.0-1.0
  - How much overlap during transition
  - Higher = smoother but more overdraw
```

### LOD Generation

```
Manual: create 3+ mesh variants in DCC tool (Blender decimate, Simplygon)
Automatic:
  - Unity LOD Generator (Package Manager)
  - Simplygon (plugin)
  - Mantis LOD Editor (Asset Store)
```

### LOD for Imposters

```
At extreme distance, replace 3D mesh with a billboard:
  - Pre-render the object from multiple angles
  - Display as a textured quad facing the camera
  - Significant performance gain for trees, distant buildings
  - Amplify Impostors (Asset Store) or custom solution
```

## Occlusion Culling

Prevents rendering objects hidden behind other objects.

### Baking

```
1. Mark occluders: Static > Occluder Static (walls, floors, large objects)
2. Mark occludees: Static > Occludee Static (objects that can be hidden)
3. Window > Rendering > Occlusion Culling
4. Set cell size and smallest occluder
5. Bake

Cell Size: spatial subdivision granularity
  - Smaller = more accurate, larger bake data
  - Start at 4-8 for indoor, 16-32 for outdoor
```

### Occlusion Areas

```
Manual override zones:
  - Add Occlusion Area component to empty GameObject
  - Size the box to cover an area
  - Mark "Is View Volume" for areas the camera can be in
  - Increases accuracy within that volume
```

### Occlusion Portals

```
For doorways and openings between rooms:
  - Occlusion Portal component
  - When portal is closed (Open = false), everything behind is culled
  - Dynamically open/close in code
```

```csharp
OcclusionPortal portal = GetComponent<OcclusionPortal>();
portal.open = doorIsOpen;
```

### Visualization

```
In Scene view: select Occlusion Culling window > Visualization tab
  - Move camera around to see what's culled (grayed out)
  - Green = visible, dark = culled
```

## Scene Organization

### Hierarchy Structure

```
--- Level_Desert ---
[Environment]
    Terrain
    Skybox
    Lighting
        DirectionalLight_Sun
        LightProbeGroup
        ReflectionProbe_Main
[Geometry]
    Buildings/
        Building_A (prefab)
        Building_B (prefab)
    Props/
        Barrel_01
        Crate_01
    Foliage/
        Tree_Cluster_01
[Gameplay]
    SpawnPoints/
        SpawnPoint_Player
        SpawnPoint_Enemy_01
    Triggers/
        Trigger_BossRoom
    Checkpoints/
        Checkpoint_01
[Audio]
    AmbientZone_Wind
    MusicTrigger_Combat
[Navigation]
    NavMesh Surface
    NavMesh Obstacles
[UI]
    Canvas_HUD
    Canvas_Pause
```

### Naming Conventions

```
PascalCase for GameObjects: Building_Warehouse_01
  - Type_Variant_Number pattern
  - Prefix categories: Trigger_, Spawn_, Audio_, Light_
  - Number suffix for duplicates: _01, _02

Folders in Hierarchy use empty GameObjects:
  - [Brackets] for organizational folders (no components)
  - Reset transform to origin
```

## Spawn Points and Markers

### Using Empty Transforms

```csharp
public class SpawnPoint : MonoBehaviour
{
    [SerializeField] private SpawnType type;
    [SerializeField] private int teamIndex;

    public enum SpawnType { Player, Enemy, Item, Vehicle }

    // Visual indicator in Scene view
    private void OnDrawGizmos()
    {
        Gizmos.color = type switch
        {
            SpawnType.Player => Color.green,
            SpawnType.Enemy => Color.red,
            SpawnType.Item => Color.yellow,
            SpawnType.Vehicle => Color.cyan,
            _ => Color.white
        };
        Gizmos.DrawWireSphere(transform.position, 0.5f);
        Gizmos.DrawRay(transform.position, transform.forward * 2f);
    }
}
```

### Finding Spawn Points

```csharp
// Via tag
GameObject[] spawns = GameObject.FindGameObjectsWithTag("SpawnPoint");

// Via component (preferred — type-safe)
SpawnPoint[] spawns = FindObjectsByType<SpawnPoint>(FindObjectsSortMode.None);
SpawnPoint playerSpawn = spawns.First(s => s.type == SpawnType.Player);

// Via parent container
Transform container = GameObject.Find("[SpawnPoints]").transform;
for (int i = 0; i < container.childCount; i++)
{
    Transform spawn = container.GetChild(i);
}
```

## NavMesh

AI navigation system for pathfinding on walkable surfaces.

### Baking NavMesh

```
1. Add NavMesh Surface component to a GameObject (or use legacy Window > Navigation)
2. Configure:
   - Agent Type: Humanoid, or create custom (radius, height, step height, slope)
   - Include Layers: which layers are walkable
   - Use Geometry: Render Meshes or Physics Colliders
3. Click Bake

NavMesh Surface (AI Navigation package — recommended over legacy):
  - Component-based, supports runtime baking
  - Multiple surfaces for different agent types
```

### NavMesh Agent

```csharp
NavMeshAgent agent = GetComponent<NavMeshAgent>();

// Set destination
agent.SetDestination(targetPosition);

// Check if arrived
if (!agent.pathPending && agent.remainingDistance <= agent.stoppingDistance)
{
    // Reached destination
}

// Properties
agent.speed = 5f;
agent.acceleration = 8f;
agent.angularSpeed = 120f;
agent.stoppingDistance = 1f;
agent.avoidancePriority = 50;  // 0 = highest priority, 99 = lowest
```

### NavMesh Obstacle

```
Dynamic obstacles that carve holes in the NavMesh:
  - Add NavMesh Obstacle component
  - Shape: Box or Capsule
  - Carve: enable for real-time NavMesh modification
  - Carve Only Stationary: enable to avoid per-frame carving (expensive)

Use for: doors, destructible walls, parked vehicles
```

### Off-Mesh Links

```
Connections between disconnected NavMesh areas:
  - Jump gaps, ladders, teleporters
  - Add Off Mesh Link component
  - Set Start and End transforms
  - Bidirectional or one-way
  - Auto-traverse or manual (for animations)

Auto-generation:
  - NavMesh Surface > Generate Links: enable
  - Drop Height: max fall distance for auto-links
  - Jump Distance: max horizontal gap for auto-links
```

## Object Placement

### Snapping

```
Grid Snapping:
  - Hold Ctrl while moving (increment snap)
  - Edit > Grid and Snap Settings
  - Set Move/Rotate/Scale snap values

Surface Snapping:
  - Hold Ctrl+Shift while moving
  - Object snaps to surface below cursor
  - Aligns to surface normal (rotation)

Vertex Snapping:
  - Hold V, hover over vertex, drag to target vertex
  - Precise alignment of mesh edges/corners
```

### ProGrids (Package)

```
Persistent grid snapping:
  - Visible 3D grid in Scene view
  - Objects snap to grid automatically
  - Toggle grid sizes (0.25, 0.5, 1.0 meters)
  - Push to Grid: align selected object to nearest grid point
```

## Environment Art Pipeline

### Importing FBX Models

```
Import Settings:
  - Scale Factor: 1.0 (if DCC tool uses meters)
    - Blender: export with "Apply Transform" and scale 1.0
    - Maya: uses cm, so Factor = 0.01 (or set to meters in Maya)
  - Convert Units: usually ON
  - Import BlendShapes: OFF if not using morph targets
  - Mesh Compression: Off for hero, Low-Medium for props
  - Generate Colliders: OFF (add manually for control)

1 Unity unit = 1 meter. All DCC exports should target this.
```

### Material Remapping

```
When importing FBX with materials:
  1. Import settings > Materials tab
  2. Material Creation Mode: Import via MaterialDescription (default)
  3. Location: Use Embedded Materials (initial), then Extract Materials
  4. Remap to project materials in the Remapped Materials list

Best practice:
  - Extract materials once, assign project materials
  - Don't edit embedded materials (they reset on reimport)
```

### Scale Reference

```
Standard measurements for scale consistency:
  - Door: 2.0m tall, 0.9m wide
  - Ceiling: 2.7-3.0m
  - Character: 1.8m (average human)
  - Step: 0.15-0.2m high, 0.3m deep
  - Railing: 0.9-1.0m
  - Road lane: 3.5m wide
  - Sidewalk: 1.5-2.0m wide

Keep a reference cube (1x1x1m) in the scene while building.
```

## Workflow Tips

### Scene Loading for Large Worlds

```csharp
// Additive scene loading — load world sections as needed
SceneManager.LoadSceneAsync("Level_Section_B", LoadSceneMode.Additive);

// Unload when player moves away
SceneManager.UnloadSceneAsync("Level_Section_A");

// Multi-scene editing in Editor:
// File > Open Scene Additive (drag scene into hierarchy)
// Set one scene as Active (lighting target)
```

### Streaming with Addressables

```csharp
// Load terrain chunk on demand
var handle = Addressables.LoadSceneAsync("TerrainChunk_2_3", LoadSceneMode.Additive);
handle.Completed += (op) => { /* chunk loaded */ };

// Unload
Addressables.UnloadSceneAsync(handle);
```

### Editor Gizmo Drawing

```csharp
// Visualize bounds, triggers, paths in Scene view
void OnDrawGizmosSelected()
{
    Gizmos.color = new Color(1, 0, 0, 0.3f);
    Gizmos.DrawCube(transform.position, triggerSize);
    Gizmos.color = Color.red;
    Gizmos.DrawWireCube(transform.position, triggerSize);
}

// Handles (Editor only) for interactive scene tools
#if UNITY_EDITOR
void OnDrawGizmos()
{
    Handles.color = Color.yellow;
    Handles.DrawWireDisc(transform.position, Vector3.up, detectionRadius);
    Handles.Label(transform.position + Vector3.up * 2f, gameObject.name);
}
#endif
```

### Performance Checklist for World Building

```
[ ] Occlusion Culling baked for indoor areas
[ ] LOD Groups on all medium/large props
[ ] Terrain pixel error ≥ 5 (higher for mobile)
[ ] Draw Instanced enabled on terrain
[ ] Static batching flags set on non-moving geometry
[ ] Light Probes placed in areas with dynamic objects
[ ] Reflection Probes: box projection for interiors
[ ] Grass/detail distance tuned (100-150m typical)
[ ] Tree billboard distance set appropriately
[ ] NavMesh obstacles use "Carve Only Stationary"
[ ] Colliders use primitives where possible (not MeshCollider)
[ ] Texture sizes appropriate for object screen size
```
