# System Overview

<!-- TEMPLATE: Replace all placeholder content with your project's actual architecture.
     Delete these instructional comments once you've filled in real data. -->

Architecture map for the [YOUR_PROJECT_NAME] codebase.

---

## Scene Graph

<!-- Document your main scene tree structure. Include node types, scripts, and key properties.
     This helps agents understand the runtime hierarchy without opening the editor. -->

```
scenes/main  [Root scene — script: main.<ext>]
├── [YourLevel]  [scenes/levels/your_level]
│   └── ...  (terrain, environment nodes)
├── [YourPlayer]  [scenes/player/player]
│   ├── CollisionShape  (collision geometry)
│   ├── Mesh / Sprite  (visual representation)
│   └── Camera  (player camera)
├── [UI Layer]  [scenes/ui/hud — UI overlay]
└── [Effects]  (particles, audio, etc.)

Singletons / Autoloads (globally accessible):
├── GameManager   (scripts/autoloads/game_manager.<ext>)
├── ...           (add your singletons here)
└── ...
```

<!-- TIP: Keep this updated as scenes change. Include:
     - Node/entity type in parentheses
     - Script/component class name if applicable
     - Key exported/serialized properties that affect gameplay
     - [same children as X] shorthand for repeated subtrees -->

---

## Scripts Inventory

<!-- List all scripts with their class, base type, and role.
     This is the master reference for "what does this file do?" -->

| File | Class | Base | Role |
|------|-------|------|------|
| `scripts/main.<ext>` | -- | Scene root type | Scene wiring: injects references into subsystems |
<!-- | `scripts/player/player.<ext>` | `Player` | Player base type | Player controller |
| `scripts/autoloads/game_manager.<ext>` | `GameManager` | Singleton base type | Game state, pause handling |
| ... | ... | ... | ... | -->

---

## Autoload Singletons

<!-- Document each autoload's signals and responsibilities.
     Agents use this to understand the global API surface. -->

| Singleton | File | Signals | Responsibilities |
|-----------|------|---------|-----------------|
<!-- | `GameManager` | `game_manager.<ext>` | `game_paused(paused: bool)` | Game state, pause tree, quit |
| `SceneManager` | `scene_manager.<ext>` | `scene_loaded(scene_name)` | Scene transitions, loading screen |
| ... | ... | ... | ... | -->

---

## Signal Map

<!-- Document ALL signals in the project. This is the key reference for understanding
     how systems communicate. Keep it complete and up-to-date.

     Convention: "Signal Up, Call Down" — autoloads emit signals; children call
     methods on parents. -->

| Signal | Emitter | Connected By | Consumer | Purpose |
|--------|---------|-------------|---------|---------|
<!-- | `game_paused(paused)` | `GameManager` | `hud.on_ready()` | `HUD` | Toggle pause overlay |
| `score_changed(new_score)` | `ScoreManager` | `main.on_ready()` | `HUD` | Update score display |
| ... | ... | ... | ... | ... | -->

<!-- TIP: Include who connects the signal (usually the consumer's initialization
     method or a parent's wiring code). This helps agents trace the full connection chain. -->

---

## Data Flow

<!-- Document how data moves through your systems each frame.
     Separate by update type: physics frame, render frame, events. -->

### Physics Frame Pipeline (fixed timestep)

<!-- Show the call chain for physics-critical code. Use indentation to show nesting. -->

```
InputManager.get_input()
  |
Player.physics_update(delta)
  |-- Read input
  |-- Apply movement
  |-- Check collisions
  |-- Update state
  |
PhysicsSubsystem.physics_update(delta)
  |-- Process interactions
  |-- Apply forces
```

### UI Update Pipeline (per frame)

<!-- Show how UI elements read and display game state each frame. -->

```
HUD.update()
  |-- Read player state (pull model)
  |-- Update labels / bars / indicators
```

### Scene Wiring (initialization)

<!-- Show how your entry point script wires systems together on load. -->

```
main.on_ready():
  find references to scene nodes
  inject dependencies (set_player, set_terrain, etc.)
  connect signals / events
  start gameplay
```

### Event Flow (signals / one-time events)

<!-- Document important event chains that don't happen every frame. -->

```
Player dies
  -> GameManager.on_player_died()
  -> emit player_died signal
  -> HUD shows death screen
  -> RespawnManager starts timer
```

---

## Dependency Graph

<!-- Show which systems depend on which. This helps agents understand what breaks
     when they change something. Use arrows to show dependency direction. -->

```
main (entry point)
  |-- depends on --> Player, Level, HUD, Effects
  |-- wires --> all subsystems together

Player
  |-- depends on --> InputManager (autoload)
  |-- read by --> HUD (pull model)
  |-- read by --> Effects (particle triggers)

HUD
  |-- depends on --> Player (reference injected by entry point)
  |-- depends on --> GameManager (signal: game_paused)

Effects
  |-- depends on --> Player (reference injected by entry point)
  |-- depends on --> Level (terrain queries)
```

<!-- TIP: If you use a system registry (SystemManifest), reference it here.
     The manifests formally declare these dependencies. -->

---

## Architecture Decision Records

<!-- Record significant architectural decisions here. Each ADR explains WHAT was
     decided, WHY, and what the consequences are. Number them sequentially.
     For a standalone ADR template, see: knowledge/architecture/adr-TEMPLATE.md -->

### ADR-1: [Title of First Decision]

**Status:** Accepted
**Decision:** [What you decided to do]
**Rationale:** [Why this approach was chosen over alternatives]
**Consequences:** [What this means for the codebase going forward]

<!-- ### ADR-2: [Title]
**Status:** Accepted / Proposed / Deprecated / Superseded by ADR-N
**Decision:** ...
**Rationale:** ...
**Consequences:** ... -->

<!-- TIP: Good ADR candidates:
     - Physics engine choice
     - Input abstraction strategy
     - Camera system approach
     - Networking architecture
     - Scene management pattern
     - Data persistence approach -->
