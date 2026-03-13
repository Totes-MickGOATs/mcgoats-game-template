---
name: godot-editor
description: "Master reference for all Godot editor workflows, MCP tools, CLI commands, justfile recipes, and custom slash commands. Use when orchestrating editor actions, discovering available tools, or planning multi-step workflows. Keywords: editor, workflow, MCP, commands, automation, justfile, pipeline."
metadata:
  source: project-specific
  version: 1.0.0
  domain: specialized
  triggers: editor, workflow, commands, automation, MCP, godot, pipeline, tools, recipes
  role: orchestrator
  scope: both
  output-format: mixed
---

# Godot Editor Workflows

Master skill for all editor-side tooling. Use this as a dispatch reference to find the right tool for any editor task.

## Quick Reference: What Tool to Use

| I want to... | Use | Type |
|:---|:---|:---|
| Run the game | `mcp__godot-mcp__run_project` or editor Play | MCP |
| Stop the game | `mcp__godot-mcp__stop_project` | MCP |
| Open the editor | `mcp__godot-mcp__launch_editor` | MCP |
| Get editor state | `mcp__godot-mcp__get_debug_output` | MCP |
| Build a scene programmatically | `/scene-build` command | Command |
| Run tests | `/dev:run-tests` | Command |
| Fix CI | `/ci:fix-ci` | Command |
| Review code | `/dev:review-code` | Command |
| Tune physics | `/physics:tune-physics` | Command |
| Build terrain assets | `/track:build-terrain` | Command |
| Check performance | `/dev:check-performance` | Command |
| Interactive test session | `/dev:test-session` | Command |
| Add a surface zone | `/track:add-surface-zone` | Command |
| Inspect a scene node | `/editor:inspect-node` | Command |
| Format GDScript | `just format` | Recipe |
| Reimport all assets | `just import` | Recipe |
| Lint + format check | `just check` | Recipe |
| Export Windows build | `just export` | Recipe |
| Generate buggy mesh | `just gen-buggy <profile>` | Recipe |
| Take a screenshot | `/editor:screenshot` | Command |
| Explore scene tree | `/editor:scene-tree` | Command |
| Get project info | `/editor:project-info` | Command |

---

## 1. MCP Tools (Godot Editor Bridge)

The `godot-mcp` server provides 100+ commands across 13 handler classes. Connection is via WebSocket to the `addons/godot_mcp/` addon running inside the Godot editor.

### System
| Tool | Action |
|:---|:---|
| `mcp__godot-mcp__get_godot_version` | Get Godot engine version |
| `mcp__godot-mcp__get_project_info` | Project name, path, main scene |
| `mcp__godot-mcp__list_projects` | List known projects |
| `mcp__godot-mcp__get_uid` | Get resource UID |
| `mcp__godot-mcp__update_project_uids` | Refresh UID cache |

### Scene Operations
| Tool | Action |
|:---|:---|
| `mcp__godot-mcp__create_scene` | Create new .tscn file |
| `mcp__godot-mcp__add_node` | Add node to scene |
| `mcp__godot-mcp__save_scene` | Save current scene |
| `mcp__godot-mcp__load_sprite` | Load texture onto Sprite2D |
| `mcp__godot-mcp__export_mesh_library` | Export MeshLibrary for GridMap |

### Runtime Control
| Tool | Action |
|:---|:---|
| `mcp__godot-mcp__run_project` | Play the game (optional scene arg) |
| `mcp__godot-mcp__stop_project` | Stop game playback |
| `mcp__godot-mcp__get_debug_output` | Read console output |
| `mcp__godot-mcp__launch_editor` | Open Godot editor |

### Extended Commands (via WebSocket)

These are available through the MCP addon's command router but may not be exposed as top-level MCP tools. They are invocable via the WebSocket protocol:

- **Node manipulation:** `get_node_properties`, `find_nodes`, `create_node`, `update_node`, `delete_node`, `reparent_node`, `connect_signal`
- **Script management:** `get_current_script`, `attach_script`, `detach_script`
- **Selection:** `get_editor_state`, `get_selected_nodes`, `select_node`
- **Debug:** `get_performance_metrics`, `get_log_messages`, `get_errors`, `get_stack_trace`
- **Screenshots:** `capture_game_screenshot`, `capture_editor_screenshot`
- **Input replay:** `get_input_map`, `execute_input_sequence`, `type_text`
- **Animation:** Full keyframe editing (15+ animation commands)
- **3D spatial:** `get_spatial_info`, `get_scene_bounds`
- **GridMap/TileMap:** Full cell manipulation (20+ commands)
- **Resources:** `get_resource_info`

See: [MCP Tools Reference](references/mcp-tools.md) | [Godot CLI Reference](references/godot-cli.md) | [Debug Keys](references/debug-keys.md) | [Editor Productivity](references/editor-productivity.md)

---

## 2. Slash Commands (`.claude/commands/`)

Commands are namespaced into subdirectories: `dev:`, `editor:`, `ci:`, `track:`, `physics:`.

### Development (`dev:`)
| Command | Purpose | Key Actions |
|:---|:---|:---|
| `/dev:run-tests` | Execute GUT test suite | `just test`, parse results, diagnose failures |
| `/dev:review-code` | Review against project conventions | `git diff`, check API usage/collision layers/etc. |
| `/dev:check-performance` | Audit for perf anti-patterns | Scan for uncached get_node(), hot loop allocations |
| `/dev:test-session` | Interactive play-test with monitoring | Launch game via MCP, poll debug output, produce report |

### Editor (`editor:`)
| Command | Purpose | Key Actions |
|:---|:---|:---|
| `/editor:scene-tree` | Explore current scene hierarchy | MCP scene tree + node inspection |
| `/editor:screenshot` | Capture editor or game screenshot | MCP screenshot tools |
| `/editor:inspect-node` | Deep-inspect a scene node | MCP node properties + script info |
| `/editor:project-info` | Get full project status | MCP project info + git status + diagnostics |
| `/editor:scene-build` | Programmatically build a scene | Plan hierarchy, execute MCP pipeline |
| `/editor:editor-health` | Check editor + addon health | Verify MCP connection, addons, DLLs |

### CI (`ci:`)
| Command | Purpose | Key Actions |
|:---|:---|:---|
| `/ci:fix-ci` | Diagnose and fix CI failures | `gh run view`, check CI_LEARNINGS.md, fix + document |

<!-- Add project-specific command categories here as you create them.
### Track (`track:`)
### Physics (`physics:`)
-->

---

## 3. Justfile Recipes

### Code Quality
```bash
just format          # Auto-format all GDScript files
just lint            # Run gdlint on scripts/ and addons/trackforge/
just format-check    # Check formatting without changes (CI mode)
just check           # format + lint + DLL check (pre-push checklist)
just check-dlls      # Verify addon DLLs are real binaries (not LFS stubs)
```

### Testing & Building
```bash
just test            # Run GUT unit tests (headless)
just import          # Force reimport all assets (headless)
just export          # Export Windows build to builds/windows/game.exe
just setup           # Install deps + configure git hooks
```

### Asset Pipeline
```bash
just build-terrain       # Full pipeline: build-outpost + pack-textures
just build-outpost       # Process outpost heightmap to EXR
just pack-textures       # Pack terrain PBR textures
just gen-buggy <profile> # Generate buggy mesh from profile JSON
just gen-heightmap       # Generate track heightmap
just gen-test-track      # Generate test track assets
just heightmap-to-exr <file>  # Convert single heightmap to EXR
```

### Release Management
```bash
just release <version>        # Tag release, bump version, generate CHANGELOG
just hotfix <version>         # Create hotfix branch from release tag
just hotfix-merge <commit>    # Cherry-pick hotfix back to master
just changelog                # Generate CHANGELOG.md via git-cliff
just changelog-preview        # Preview unreleased changes
```

### Performance & Utilities
```bash
just benchmark                       # Run in-game benchmark (F8 trigger)
just benchmark-compare <base> <cur>  # Compare benchmarks (10% threshold)
just benchmark-save                  # Save current as baseline
just godot-cmd <command> [args]      # Send command to Godot via MCP bridge
just clean                           # Delete build artifacts + cache
```

---

## 4. Python Tool Scripts (`scripts/tools/`)

### Asset Generators
| Script | Purpose |
|:---|:---|
| `gen_buggy_mesh.py` | Generate vehicle .glb from profile JSON (trimesh) |
| `gen_buggy_profiles.py` | Generate default buggy profile data |
| `gen_track_heightmap.py` | Generate track heightmap |
| `gen_detail_texture.py` | Procedural detail texture |
| `gen_macro_normal.py` | Macro normal maps |
| `gen_tire_stamp.py` | Tire track stamp texture |
| `pack_terrain_textures.py` | Pack Poly Haven PBR textures |
| `heightmap_to_exr.py` | Heightmap image to EXR conversion |
| `generate_test_track_assets.py` | Test track asset pipeline |
| `process_outpost_assets.py` | Outpost terrain processing |
| `generate_grid_materials.py` | Grid shader materials |
| `fbx_to_glb.py` | FBX to GLB model conversion |

### Utilities
| Script | Purpose |
|:---|:---|
| `compare_benchmark.py` | Compare benchmark JSON files (10% threshold) |
| `download_sonniss.py` | Download sound assets from Sonniss |
| `convert_manual_pdfs.py` | Convert manual PDFs |

### Godot Editor Scripts (@tool)
| Script | Purpose |
|:---|:---|
| `import_track_heightmap.gd` | Import R16 heightmap into Terrain3D (run from Script Editor) |
| `gen_track_barriers.gd` | Place barriers along track edges from centerline JSON |
| `perf_benchmark.gd` | In-game F8 performance capture |

---

## 5. Git Hooks (`.githooks/`)

### pre-commit (6 checks)
1. **gdlint** — Style lint on all staged .gd files
2. **gdformat --check** — Formatting verification
3. **Bare print() rejection** — Must use `Debug` autoload (exempt: debug.gd, @tool scripts)
4. **HSlider FOCUS_NONE** — Warn if HSlider added without FOCUS_NONE
5. **Direct Input.\* rejection** — Must use InputManager abstraction
6. **Stretch aspect "keep"** — Must be "expand" for ultrawide support

### LFS hooks
- `pre-push`, `post-commit`, `post-checkout`, `post-merge` — Git LFS integration

---

## 6. Debug Keys (In-Game)

| Key | Action | System |
|:---|:---|:---|
| F1 | Toggle TuningPanel | TuningPanel |
| F3 | Debug overlay manager | DebugOverlayManager |
| F4 | Cycle graphics tier | GraphicsManager |
| F5 | Toggle DOF mode | GraphicsManager |
| F6 | Debug draw 3D | DebugDraw3D |
| F7 | Debug canvas 2D | DebugCanvas2D |
| F8 | Performance benchmark | perf_benchmark.gd |
| F9 | Network stats HUD | NetStatsHUD |

---

## 7. Workflow Recipes

### "I need to add a new feature"
1. `/dev:run-tests` — verify baseline passes
2. Write failing test (TDD — mandatory)
3. Implement feature
4. `just check` — lint + format
5. `/dev:review-code` — verify conventions
6. `/dev:run-tests` — verify all pass
7. Commit with `feat:` prefix

### "The game has a visual bug"
1. `/dev:test-session` — interactive play-test with monitoring
2. `/editor:screenshot` — capture the issue
3. Inspect relevant nodes via `/editor:inspect-node`
4. Fix + test + commit

### "CI is red"
1. `/ci:fix-ci` — automated diagnosis + fix

### "I need to build a new track"
1. `/track:build-terrain` — run asset pipeline
2. `just import` — reimport assets headless
3. Edit terrain in Godot editor (Terrain3D)
4. `/track:add-surface-zone` — define surface zones
5. Place checkpoints + racing line
6. `/dev:test-session` — play-test the track

### "I need to optimize performance"
1. `/dev:check-performance` — scan for anti-patterns
2. `just benchmark` — capture baseline (F8 in-game)
3. Fix issues found
4. `just benchmark-compare` — verify improvement

### "I need to check project health"
1. `/editor:editor-health` — verify tooling, addons, DLLs
2. `/editor:project-info` — full dashboard

---

## 8. Godot CLI (Direct Invocation)

For operations that bypass MCP and run Godot directly:

```bash
# Force reimport all assets (headless)
godot -e --quit-after 2 --headless

# Run a batch EditorScript
godot --headless -s scripts/tools/my_batch_job.gd

# Export Windows build
godot -v --export-release --headless "Windows Desktop" builds/windows/game.exe
```

See: [Godot CLI Reference](references/godot-cli.md)

### EditorScript Quick Pattern
For one-off batch operations (run via Ctrl+Shift+X in the editor):
```gdscript
@tool
extends EditorScript

func _run():
    var root = get_editor_interface().get_edited_scene_root()
    for node in root.find_children("*", "Area3D"):
        node.collision_layer = 0b100  # Layer 3 = Obstacles
```

Existing @tool scripts in the project:
- `scripts/tools/import_track_heightmap.gd` — Import R16 heightmap into Terrain3D
- `scripts/tools/gen_track_barriers.gd` — Place barriers along track edges

---

## Related Skills

- [terrain3d](../terrain3d/SKILL.md) — Terrain3D v1.0.1 complete guide
- [trackforge](../trackforge/SKILL.md) — TrackForge editor plugin
- [godot-mcp-scene-builder](../godot-mcp-scene-builder/SKILL.md) — Programmatic scene building
- [godot-mcp-setup](../godot-mcp-setup/SKILL.md) — MCP server installation
- [godot-master](../godot-master/SKILL.md) — Comprehensive Godot reference (120+ docs)
- [godot-performance-optimization](../godot-performance-optimization/SKILL.md) — Performance patterns
- [godot-testing-patterns](../godot-testing-patterns/SKILL.md) — GUT testing patterns
