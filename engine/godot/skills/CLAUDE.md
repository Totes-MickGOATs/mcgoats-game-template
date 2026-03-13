# Godot Skills Index

This directory contains 47 Godot-specific skills for game development with Godot 4.x and GDScript. Each skill is a self-contained reference document in `<skill-name>/SKILL.md`.

## How to Use

Load a skill when you need deep guidance on a specific topic. Skills are designed for lazy-loading -- read only the ones relevant to your current task.

---

## Available Skills

### Core GDScript & Architecture

| Skill | Description |
|-------|-------------|
| [godot-gdscript-mastery](godot-gdscript-mastery/SKILL.md) | Static typing, signal architecture, unique nodes, code structure, performance patterns |
| [godot-gdscript-patterns](godot-gdscript-patterns/SKILL.md) | Production patterns: state machines, autoloads, resources, object pooling, components |
| [godot-signal-architecture](godot-signal-architecture/SKILL.md) | Signal Up/Call Down pattern, typed signals, event buses, signal chains, one-shot connections |
| [godot-autoload-architecture](godot-autoload-architecture/SKILL.md) | Singleton patterns, global state management, service locators, initialization order |
| [godot-composition](godot-composition/SKILL.md) | Entity-Component architecture for games (RPGs, platformers, shooters) |
| [godot-composition-apps](godot-composition-apps/SKILL.md) | Composition patterns for scalable Godot applications, tools, and UI |
| [godot-state-machine-advanced](godot-state-machine-advanced/SKILL.md) | Hierarchical state machines, pushdown automata, state stacks, sub-state machines |
| [godot-resource-data-patterns](godot-resource-data-patterns/SKILL.md) | Data-oriented design with Resource/RefCounted classes, item databases, typed arrays |
| [godot-master](godot-master/SKILL.md) | Comprehensive master skill consolidating 86 specialized blueprints |

### Scene & Project Management

| Skill | Description |
|-------|-------------|
| [godot-scene-management](godot-scene-management/SKILL.md) | Async scene loading, transitions, instance pooling, caching, loading screens |
| [godot-project-foundations](godot-project-foundations/SKILL.md) | Project organization, folder structures, naming conventions, version control |
| [godot-project-templates](godot-project-templates/SKILL.md) | Genre-specific project boilerplates (2D platformer, top-down RPG, 3D FPS) |
| [godot-save-load-systems](godot-save-load-systems/SKILL.md) | JSON/binary serialization, PERSIST group pattern, versioning, migration |
| [godot-editor](godot-editor/SKILL.md) | Editor workflows, MCP tools, CLI commands, justfile recipes, automation |

### UI & Frontend

| Skill | Description |
|-------|-------------|
| [godot-ui-design](godot-ui-design/SKILL.md) | Complete UI/menu system patterns, StyleBox recipes, scene management (renamed from godot-frontend-design) |
| [godot-ui-containers](godot-ui-containers/SKILL.md) | Responsive layouts with HBox, VBox, Grid, Margin, Scroll containers |
| [godot-ui-rich-text](godot-ui-rich-text/SKILL.md) | RichTextLabel with BBCode, custom effects, clickable links, meta tags |
| [godot-ui-theming](godot-ui-theming/SKILL.md) | Theme resources, StyleBoxes, custom fonts, consistent visual styling |
| [godot-tweening](godot-tweening/SKILL.md) | Tween-based animation, easing functions, UI juice, camera movements |

### Input & Camera

| Skill | Description |
|-------|-------------|
| [godot-input-handling](godot-input-handling/SKILL.md) | InputMap actions, gamepad support, rebinding, deadzones, input buffering |
| [godot-camera-systems](godot-camera-systems/SKILL.md) | 2D/3D camera follow, shake (trauma system), deadzone, look-ahead, transitions |

### Physics

| Skill | Description |
|-------|-------------|
| [godot-physics-3d](godot-physics-3d/SKILL.md) | Jolt physics, ragdolls, joints, raycasting, collision layers (3D) |
| [godot-2d-physics](godot-2d-physics/SKILL.md) | Collision layers/masks, Area2D triggers, raycasting, physics queries (2D) |

### Audio

| Skill | Description |
|-------|-------------|
| [godot-audio-systems](godot-audio-systems/SKILL.md) | AudioStreamPlayer variants, bus architecture, pooling, crossfade, procedural audio |

### 3D Graphics & World

| Skill | Description |
|-------|-------------|
| [godot-3d-lighting](godot-3d-lighting/SKILL.md) | DirectionalLight3D, OmniLight3D, SpotLight3D, VoxelGI, SDFGI, shadow cascades |
| [godot-3d-materials](godot-3d-materials/SKILL.md) | PBR materials, StandardMaterial3D, albedo, metallic/roughness, normal maps, ORM |
| [godot-3d-world-building](godot-3d-world-building/SKILL.md) | GridMap, CSG geometry, WorldEnvironment, ProceduralSkyMaterial, level design |
| [godot-shaders-basics](godot-shaders-basics/SKILL.md) | Shader programming, visual effects, post-processing, canvas/spatial shaders |
| [godot-particles](godot-particles/SKILL.md) | GPUParticles2D/3D, ParticleProcessMaterial, gradients, sub-emitters |

### 2D Specific

| Skill | Description |
|-------|-------------|
| [godot-tilemap-mastery](godot-tilemap-mastery/SKILL.md) | TileMapLayer, TileSet, terrain autotiling, physics layers, custom data |

### Procedural & Generation

| Skill | Description |
|-------|-------------|
| [godot-procedural-generation](godot-procedural-generation/SKILL.md) | Dungeons, terrain, loot, levels using FastNoiseLite, BSP, WFC, random walks |

### Testing & Debugging

| Skill | Description |
|-------|-------------|
| [godot-testing-patterns](godot-testing-patterns/SKILL.md) | GUT framework, TDD cycle, assertions, mocking, async testing, signal testing |
| [godot-debugging-profiling](godot-debugging-profiling/SKILL.md) | Print debugging, breakpoints, Godot Debugger, profiler, error handling |

### Performance & Optimization

| Skill | Description |
|-------|-------------|
| [godot-performance-optimization](godot-performance-optimization/SKILL.md) | Profiler-driven analysis, object pooling, visibility culling, draw call reduction |
| [game-optimization-performance](game-optimization-performance/SKILL.md) | Project-specific optimization: audio smoothing, frame budgets, benchmark patterns |
| [godot-server-architecture](godot-server-architecture/SKILL.md) | Low-level server access (RenderingServer, PhysicsServer) using RIDs for max perf |

### Platform & Export

| Skill | Description |
|-------|-------------|
| [godot-export-builds](godot-export-builds/SKILL.md) | Multi-platform exports, CLI builds, CI/CD pipelines, code signing |
| [godot-platform-desktop](godot-platform-desktop/SKILL.md) | Windows/Linux/macOS: keyboard/mouse, settings menus, window management |
| [godot-platform-console](godot-platform-console/SKILL.md) | PlayStation/Xbox/Switch: controller-first UI, certification (TRCs/TCRs) |

### Genre-Specific

| Skill | Description |
|-------|-------------|
| [godot-genre-racing](godot-genre-racing/SKILL.md) | Vehicle physics, checkpoints, rubber-banding AI, lap systems |
| [godot-genre-sandbox](godot-genre-sandbox/SKILL.md) | Physics interactions, cellular automata, emergent gameplay, creative tools |
| [godot-genre-simulation](godot-genre-simulation/SKILL.md) | Economy management, time progression, tycoon systems, agent AI |
| [godot-genre-sports](godot-genre-sports/SKILL.md) | Physics-based ball interaction, team AI formations, contextual input |

### MCP & Tooling

| Skill | Description |
|-------|-------------|
| [godot-mcp-scene-builder](godot-mcp-scene-builder/SKILL.md) | Programmatic scene creation/modification via MCP tools |
| [godot-mcp-setup](godot-mcp-setup/SKILL.md) | MCP server installation and configuration for Godot |
| [godot-skill-discovery](godot-skill-discovery/SKILL.md) | Skill indexing and discovery system for AI agents |
| [godot-skill-judge](godot-skill-judge/SKILL.md) | Meta-skill for validating skill integrity and quality |
