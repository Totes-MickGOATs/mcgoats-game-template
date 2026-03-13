<!-- Copied to .claude/commands/editor/ by tools/setup-engine.sh when Godot is selected -->
Capture a screenshot from the Godot editor or running game.

1. **Determine target** from $ARGUMENTS or context:
   - `game` — capture the running game viewport
   - `editor` — capture the editor viewport
   - If unspecified, check if the game is running. If yes, capture game. If no, capture editor.

2. **If capturing game:**
   - Verify the game is running via `mcp__godot-mcp__get_debug_output`
   - If not running, ask user: "Game isn't running. Should I start it first, or capture the editor instead?"
   - Capture via the game bridge screenshot command

3. **If capturing editor:**
   - Capture via the editor screenshot command (3D viewport by default)

4. **Display the screenshot** to the user and describe what's visible:
   - Scene composition
   - Any visual issues (z-fighting, missing textures, clipping)
   - UI element state if visible

5. **Offer follow-up actions:**
   - "Would you like me to inspect any specific node visible in the screenshot?"
   - "Should I capture from a different angle/viewport?"
