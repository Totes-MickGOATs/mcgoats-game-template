# Godot Engine Setup

## Prerequisites

- **Godot 4.x** (stable, GDScript build — not Mono/.NET)
  - Download from [godotengine.org](https://godotengine.org/download/) or install via `winget install GodotEngine.GodotEngine`
  - Verify: `godot --version` should print `4.x.x.stable`

## Steps

### 1. Install gdtoolkit (linting & formatting)

```bash
uv add --dev "gdtoolkit>=4.5"
```

This provides `gdlint`, `gdformat`, and `gdparse` commands.

### 2. Lint configs

The setup script copies `gdlintrc` and `gdformatrc` to the project root. These configure:
- **Line length:** 120 characters
- **Relaxed rules:** `max-public-methods` and `max-returns` disabled (common in game dev)

### 3. Open project in Godot editor

```bash
godot --editor
```

This generates the `.godot/` directory (import cache, shader cache, etc.). You must do this before running tests.

### 4. Configure MCP (optional)

The Godot MCP bridge enables Claude Code to interact with the running Godot editor.

- The `.mcp.json` file is copied to the project root by the setup script
- Requires `tools/godot_mcp_bridge.py` (write your own or adapt from reference projects)
- The Godot editor must have the MCP addon enabled

### 5. Run your first test

```bash
just test-fast <test_file>
```

This uses the GUT (Godot Unit Testing) framework. Test files live in `tests/` and follow the naming convention `test_<system>.gd`.

## Worktree Support

When working in git worktrees, seed the import cache before running Godot:

```bash
just seed-import
```

This creates a directory junction/symlink to the main repo's `.godot/imported/` directory, avoiding a full reimport.

## Directory Structure

```
addons/          # Third-party addons (GUT, etc.)
scripts/         # All GDScript source files
scenes/          # Godot scene files (.tscn)
resources/       # Resources, materials, manifests
tests/           # GUT test files (test_*.gd)
```
