<!-- Copied to .claude/commands/editor/ by tools/setup-engine.sh when Godot is selected -->
Deep-inspect a node in the current Godot scene. The node path should be provided as $ARGUMENTS (e.g., `/inspect-node Player/Camera3D`).

1. **Identify the target node** from arguments. If no path given, ask the user which node to inspect.

2. **Gather information** using available tools:
   - Use `find_symbol` or Grep to find the attached script and read its exports/properties
   - Use MCP tools if the editor is running to get live property values
   - Read the relevant .tscn file to get scene-level overrides

3. **Report the following:**

   **Identity**
   - Node name and type
   - Scene file it belongs to
   - Parent node path

   **Script**
   - Attached script path (if any)
   - Key exported properties and their values
   - Signals defined and connected

   **Transform** (for Node3D)
   - Position, rotation, scale (local and global if available)

   **Physics** (for physics bodies)
   - Collision layer and mask
   - Mass, friction, bounce
   - Contact monitoring settings

   **Children**
   - List of direct children with types

4. **Flag any issues:**
   - Missing collision shapes on physics bodies
   - Exported properties at default values that look wrong
   - Collision layer mismatches with project conventions
   - Missing scripts on nodes that typically need them

5. **Suggest related actions** based on what was found.
