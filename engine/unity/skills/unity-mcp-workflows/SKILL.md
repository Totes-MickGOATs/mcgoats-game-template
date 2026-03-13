# Unity MCP Workflows

Using MCP (Model Context Protocol) tools to interact with Unity Editor from Claude Code. Two MCP servers are available: **UnityMCP** and **coplay-mcp**.

## Setup

Both servers are configured in `.mcp.json` at the project root:

```json
{
  "mcpServers": {
    "UnityMCP": {
      "command": "npx",
      "args": ["-y", "@anthropic/unity-mcp@latest"]
    },
    "coplay-mcp": {
      "command": "npx",
      "args": ["-y", "coplay-mcp@latest"]
    }
  }
}
```

**Prerequisites:**
- Unity Editor must be open with the project loaded
- The corresponding Unity package/addon must be installed in the project
- Node.js/npx available on PATH

## UnityMCP Tools

UnityMCP provides structured, domain-specific tools for Unity Editor manipulation.

### Scene Management — `manage_scene`

```
action: "get_hierarchy"
  page_size: 50          # paginate large scenes
  cursor: "next_page_id" # from previous response

action: "load"
  path: "Assets/Scenes/MainMenu.unity"

action: "save"
  # saves the currently open scene
```

**Best practice:** Always use `get_hierarchy` with `page_size` for scenes with many objects. Start with `page_size: 50` and paginate if needed.

### GameObject Operations — `manage_gameobject`

```
action: "create"
  name: "Player"
  parent: "GameWorld"        # optional parent by name
  position: [0, 1, 0]
  rotation: [0, 0, 0]
  scale: [1, 1, 1]

action: "modify"
  name: "Player"
  position: [5, 0, 3]

action: "get_components"
  name: "Player"
  include_properties: false  # start with false for overview
  page_size: 20

action: "get_components"
  name: "Player"
  include_properties: true   # then true for specific object details
```

**Important:** Use `include_properties: false` first to see what components exist. Then query with `include_properties: true` only when you need property values. This avoids huge responses.

### Component Operations — `manage_components`

```
action: "add"
  game_object: "Player"
  component_type: "Rigidbody"

action: "modify"
  game_object: "Player"
  component_type: "Rigidbody"
  properties: {
    "mass": 2.0,
    "drag": 0.5,
    "useGravity": true,
    "isKinematic": false
  }

action: "remove"
  game_object: "Player"
  component_type: "AudioSource"
```

### Finding Objects — `find_gameobjects`

```
# Search by name (partial match)
search_type: "name"
query: "Enemy"

# Search by tag
search_type: "tag"
query: "Player"

# Search by layer
search_type: "layer"
query: "UI"

# Search by component type
search_type: "component"
query: "Rigidbody"
```

### Script Management — `manage_script`

```
action: "create"
  name: "PlayerController"
  path: "Assets/Scripts/Player"
  template: "MonoBehaviour"    # or "ScriptableObject", "Editor", etc.

action: "modify"
  path: "Assets/Scripts/Player/PlayerController.cs"
  content: "... full file content ..."
```

**Critical workflow after script changes:**

1. Create or modify the script
2. Call `read_console` to check for compilation errors
3. Wait if `editor_state.isCompiling` is true
4. Only proceed when compilation succeeds

### Console — `read_console`

```
# Check for errors after script changes
log_type: "error"     # "log", "warning", "error", or "all"
count: 10             # number of recent entries

# Always check after:
# - Creating a new script
# - Modifying an existing script
# - Adding/removing components that depend on scripts
```

### Editor Control — `manage_editor`

```
action: "play"    # Enter Play mode
action: "pause"   # Pause Play mode
action: "stop"    # Exit Play mode
action: "build"   # Build the project
  platform: "StandaloneWindows64"
  path: "Builds/Game.exe"
```

### Asset Management — `manage_asset`

```
action: "search"
  query: "Player"
  type: "Prefab"    # "Prefab", "Material", "Texture", "Script", etc.

action: "import"
  path: "Assets/Models/character.fbx"

action: "create"
  type: "Material"
  name: "PlayerMaterial"
  path: "Assets/Materials"
```

### Visual Pipeline Tools

```
# Materials
manage_material:
  action: "create" / "modify"
  name: "MetalFloor"
  shader: "Universal Render Pipeline/Lit"
  properties: { "_BaseColor": [0.8, 0.8, 0.8, 1.0], "_Metallic": 0.9 }

# Textures
manage_texture:
  action: "get_info" / "modify_import"
  path: "Assets/Textures/floor_albedo.png"

# Shaders
manage_shader:
  action: "list" / "get_properties"

# Prefabs
manage_prefabs:
  action: "create" / "modify" / "get_info"

# UI
manage_ui:
  action: "create" / "modify"
  # Canvas, panels, buttons, etc.

# VFX
manage_vfx:
  action: "create" / "modify"
  # Particle systems, VFX Graph
```

## coplay-mcp Tools

coplay-mcp provides a broader set of tools including AI content generation and more granular object manipulation.

### Object Creation and Manipulation

```
# Create a new GameObject
create_game_object:
  name: "Enemy"
  parent_path: "/GameWorld/Enemies"  # hierarchy path

# Set transform
set_transform:
  object_path: "/GameWorld/Enemies/Enemy"
  position: { "x": 0, "y": 1, "z": 5 }
  rotation: { "x": 0, "y": 180, "z": 0 }
  scale: { "x": 1, "y": 1, "z": 1 }

# Set any serialized property
set_property:
  object_path: "/Player"
  component_type: "PlayerController"
  property_name: "moveSpeed"
  value: 7.5

# Add component
add_component:
  object_path: "/Player"
  component_type: "UnityEngine.AudioSource"

# Remove component
remove_component:
  object_path: "/Player"
  component_type: "UnityEngine.AudioSource"
```

### Prefabs

```
# Create prefab from scene object
create_prefab:
  source_object_path: "/Player"
  prefab_path: "Assets/Prefabs/Player.prefab"

# Place prefab in scene
place_asset_in_scene:
  asset_path: "Assets/Prefabs/Enemy.prefab"
  position: { "x": 10, "y": 0, "z": 5 }
  parent_path: "/GameWorld/Enemies"
```

### Scene Operations

```
create_scene:
  scene_name: "Level02"
  path: "Assets/Scenes"

open_scene:
  scene_path: "Assets/Scenes/Level02.unity"

save_scene:
  # saves current scene
```

### Materials and Rendering

```
create_material:
  name: "EnemyMaterial"
  shader: "Universal Render Pipeline/Lit"
  path: "Assets/Materials"

assign_material:
  object_path: "/Enemy"
  material_path: "Assets/Materials/EnemyMaterial.mat"

assign_shader_to_material:
  material_path: "Assets/Materials/EnemyMaterial.mat"
  shader_name: "Universal Render Pipeline/Lit"
```

### Input System

```
create_input_action_asset:
  name: "PlayerControls"
  path: "Assets/Input"

add_action_map:
  asset_path: "Assets/Input/PlayerControls.inputactions"
  map_name: "Gameplay"

add_bindings:
  asset_path: "Assets/Input/PlayerControls.inputactions"
  action_map: "Gameplay"
  action_name: "Move"
  bindings: [
    { "path": "<Keyboard>/w", "name": "up" },
    { "path": "<Gamepad>/leftStick" }
  ]
```

### Animation

```
create_animator_controller:
  name: "EnemyAnimator"
  path: "Assets/Animations"

create_animation_clip:
  name: "EnemyIdle"
  path: "Assets/Animations"

# Apply animation to a rigged model
apply_animation_to_rigged_model:
  model_path: "/Enemy"
  controller_path: "Assets/Animations/EnemyAnimator.controller"
```

### Gameplay Testing

```
play_game:
  # Enters Play mode

stop_game:
  # Exits Play mode

# Visual feedback
capture_scene_object:
  object_path: "/Player"
  # Returns screenshot of the object

capture_ui_canvas:
  canvas_path: "/UI/MainCanvas"
  # Returns screenshot of the UI
```

### Execute Arbitrary C#

The most powerful coplay-mcp tool — run any C# code in the editor:

```
execute_script:
  code: |
    var player = GameObject.Find("Player");
    var rb = player.GetComponent<Rigidbody>();
    Debug.Log($"Player mass: {rb.mass}, velocity: {rb.velocity}");

execute_script:
  code: |
    // Batch operations
    var enemies = GameObject.FindGameObjectsWithTag("Enemy");
    foreach (var enemy in enemies)
    {
        var ai = enemy.GetComponent<EnemyAI>();
        if (ai != null) ai.detectionRange = 15f;
    }
    Debug.Log($"Updated {enemies.Length} enemies");
```

### AI Content Generation

coplay-mcp includes AI-powered content generation:

```
generate_3d_model_from_text:
  prompt: "low-poly medieval sword"
  output_path: "Assets/Models/Generated"

generate_3d_model_from_image:
  image_path: "Assets/References/concept_art.png"
  output_path: "Assets/Models/Generated"

generate_sfx:
  prompt: "laser gun firing"
  output_path: "Assets/Audio/SFX"

generate_music:
  prompt: "upbeat chiptune battle theme"
  duration: 30
  output_path: "Assets/Audio/Music"

generate_or_edit_images:
  prompt: "sci-fi metal floor texture, seamless, PBR"
  output_path: "Assets/Textures/Generated"
```

### File Operations

```
list_files:
  path: "Assets/Scripts"
  recursive: true

read_file:
  path: "Assets/Scripts/PlayerController.cs"

search_files:
  query: "PlayerController"
  path: "Assets/Scripts"

list_game_objects_in_hierarchy:
  # Returns full scene hierarchy
```

### Package Management

```
list_packages:
  # Lists installed packages

search_all_packages:
  query: "cinemachine"

install_unity_package:
  package_name: "com.unity.cinemachine"

install_git_package:
  url: "https://github.com/user/repo.git"

remove_unity_package:
  package_name: "com.unity.cinemachine"
```

## Workflow Best Practices

### 1. Always Check Compilation After Script Changes

```
Step 1: manage_script action:"modify" (or create)
Step 2: read_console log_type:"error"
Step 3: If errors → fix and repeat
Step 4: If clean → proceed
```

### 2. Use Paging for Large Scenes

```
Step 1: manage_scene action:"get_hierarchy" page_size:50
Step 2: Check if there's a cursor for next page
Step 3: Continue paging until all objects are retrieved (or you found what you need)
```

### 3. Properties Query Strategy

```
Step 1: manage_gameobject action:"get_components" include_properties:false
        → See which components exist (lightweight response)
Step 2: manage_gameobject action:"get_components" include_properties:true
        → Only when you need actual property values
```

### 4. Check Editor State Before Proceeding

Before performing operations that depend on compilation:

```
Step 1: Check editor_state.isCompiling in responses
Step 2: If compiling, wait and re-check
Step 3: Only proceed when compilation is complete
```

### 5. Use Resources for Reads, Tools for Mutations

- **Reading** scene hierarchy, component data, file contents → use resource endpoints when available (faster, cached)
- **Modifying** objects, creating assets, changing properties → use tool endpoints (these modify state)

### 6. Batch Operations with execute_script

When you need to modify many objects at once, `execute_script` is more efficient than calling individual tools:

```
execute_script:
  code: |
    // Disable all enemies at once
    foreach (var enemy in GameObject.FindGameObjectsWithTag("Enemy"))
    {
        enemy.SetActive(false);
    }
```

### 7. Verify Changes Visually

After significant changes, use `capture_scene_object` or `capture_ui_canvas` to verify the result looks correct before moving on.

## Choosing Between UnityMCP and coplay-mcp

| Task | Preferred Server |
|------|-----------------|
| Scene hierarchy queries | UnityMCP (`manage_scene` with paging) |
| Component property reads | UnityMCP (`manage_gameobject` with include_properties) |
| Creating/placing prefabs | coplay-mcp (`create_prefab`, `place_asset_in_scene`) |
| Input System setup | coplay-mcp (full input action asset workflow) |
| Animation setup | coplay-mcp (animator controllers, clips) |
| Batch operations | coplay-mcp (`execute_script`) |
| AI content generation | coplay-mcp (3D models, SFX, music, images) |
| Visual verification | coplay-mcp (`capture_scene_object`) |
| Material/shader work | Either (both have material tools) |
| Script creation | Either (both can create/modify scripts) |

When both servers can do a task, prefer the one with more specific tooling for that domain. For complex multi-step operations, coplay-mcp's `execute_script` is the most flexible option.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| MCP server not connecting | Ensure Unity Editor is open and the MCP addon/package is installed and enabled |
| Tools return errors | Check `read_console` for Unity errors. Editor may need a script recompile. |
| Slow hierarchy queries | Use `page_size` parameter, start with 50. Don't query `include_properties: true` unnecessarily. |
| Script changes not taking effect | Check `editor_state.isCompiling`. Wait for compilation to complete. |
| `execute_script` errors | Ensure the C# code is valid. Check for missing `using` statements. Results appear in read_console. |
| Objects not found by name | Names are case-sensitive. Use `find_gameobjects` to search. Hierarchy paths use `/` separators. |
