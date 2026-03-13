<!-- Copied to .claude/commands/editor/ by tools/setup-engine.sh when Godot is selected -->
Programmatically build a Godot scene using MCP tools. This is the orchestrator for complex scene creation.

## Procedure

1. **Understand the request** from $ARGUMENTS and conversation context. If the request is vague, ask for:
   - Scene purpose (gameplay, UI, editor tool)
   - Root node type (Node3D, CharacterBody3D, Control, etc.)
   - Key child nodes needed
   - Where to save (default: `res://scenes/`)

2. **Design the node hierarchy** before touching any tools:
   ```
   Root (Type)
   +-- Child1 (Type) [script: path.gd]
   +-- Child2 (Type)
       +-- Grandchild (Type)
   ```
   Present the plan to the user and wait for confirmation.

3. **Check prerequisites:**
   - Verify MCP connection via `mcp__godot-mcp__get_project_info`
   - Verify the target directory exists
   - Check for naming conflicts with existing scenes

4. **Execute the build pipeline:**
   a. `mcp__godot-mcp__create_scene` — create the .tscn file with root node
   b. `mcp__godot-mcp__add_node` — add each child node sequentially (parent must exist before children)
   c. Set node properties via `update_node` if needed
   d. `mcp__godot-mcp__save_scene` — save the result

5. **Create scripts** if needed:
   - Write .gd files using the Write tool
   - Follow project coding standards (see CLAUDE.md and coding conventions)
   - Attach scripts via `attach_script` command

6. **Verify the result:**
   - Open the scene in the editor
   - Check for errors in debug output
   - Report the final node tree

## Rules
- Always use `res://` paths, never absolute paths
- Follow the project's collision layer conventions
- Set FOCUS_NONE on any HSlider nodes
- Set MOUSE_FILTER_IGNORE on visual-only overlays
- All CanvasLayer menus need PROCESS_MODE_ALWAYS
