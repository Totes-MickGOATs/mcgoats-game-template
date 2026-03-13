<!-- Copied to .claude/commands/editor/ by tools/setup-engine.sh when Godot is selected -->
Explore the current scene hierarchy in the Godot editor. Follow this procedure:

1. **Get editor state** via `mcp__godot-mcp__get_debug_output` to confirm the editor is running and which scene is open.

2. **Get project info** via `mcp__godot-mcp__get_project_info` to understand the project context.

3. **If a specific node path is provided** (as $ARGUMENTS), inspect that node's properties and children. Otherwise, present the full scene tree structure.

4. **For each interesting node**, note:
   - Node type (Node3D, RigidBody3D, Area3D, etc.)
   - Attached script (if any)
   - Key properties (transform, visibility, collision layers)
   - Child count

5. **Present the tree** in a clear hierarchical format with type annotations:
   ```
   Root (Node3D)
   +-- Environment (Node3D)
   |   +-- Terrain (StaticBody3D)
   |   +-- Lights (Node3D)
   +-- Player (CharacterBody3D) [script: player.gd]
   |   +-- Camera3D
   |   +-- CollisionShape3D
   +-- UI (CanvasLayer)
       +-- HUD (Control) [script: hud.gd]
   ```

6. **Highlight** any nodes with warnings, missing scripts, or unusual configurations.
