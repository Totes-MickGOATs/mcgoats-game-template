# Godot Frontend Design Skill
# Menu System Patterns, Recipes & Conventions

This skill document encodes all Godot 4 UI patterns, StyleBox recipes, scene management approaches,
and project-specific conventions needed to build a game menu system.

---

## A. UI Architecture Fundamentals

### A.1 Control Node Hierarchy

Every Godot UI element is a `Control` node. All UI is built from the core container primitives:

| Container | Purpose |
|-----------|---------|
| `VBoxContainer` | Vertical stack of children |
| `HBoxContainer` | Horizontal stack of children |
| `MarginContainer` | Adds padding around a single child |
| `PanelContainer` | Panel background + single content child |
| `CenterContainer` | Centers a single child horizontally + vertically |
| `GridContainer` | Grid layout (set `columns`) |
| `ScrollContainer` | Scrollable viewport around content |
| `TabContainer` | Tabbed pages |
| `AspectRatioContainer` | Preserves child aspect ratio |
| `SubViewportContainer` | Embeds a 3D/2D SubViewport into the UI |

**Key rule**: Never size or position `Control` nodes manually unless anchors/offsets are not enough.
Always prefer containers — they handle resize, DPI scaling, and aspect changes automatically.

### A.2 Anchor & Offset System

Anchors are [0.0–1.0] relative to the parent. Offsets are pixel offsets from the anchor point.

```gdscript
# Full-screen Control (covers parent)
ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Centered fixed-size panel (800×500)
ctrl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
ctrl.custom_minimum_size = Vector2(800, 500)

# Bottom strip (HUD bar)
ctrl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
ctrl.offset_top = -80.0  # 80px tall from bottom

# Top-right corner label
ctrl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
ctrl.offset_left  = -200.0
ctrl.offset_bottom = 40.0
```

Common presets: `PRESET_FULL_RECT`, `PRESET_CENTER`, `PRESET_TOP_WIDE`, `PRESET_BOTTOM_WIDE`,
`PRESET_LEFT_WIDE`, `PRESET_RIGHT_WIDE`, `PRESET_TOP_LEFT`, `PRESET_TOP_RIGHT`,
`PRESET_BOTTOM_LEFT`, `PRESET_BOTTOM_RIGHT`.

### A.3 CanvasLayer Stacking (Project Convention)

CanvasLayer `layer` property controls draw order. Higher = drawn on top.

| Layer | Owner | Purpose |
|-------|-------|---------|
| 0 | Gameplay 3D | Rendered before any UI |
| 1 | `HUD` | Speed, lap time, airborne indicator |
| 5 | `SceneManager` / Menus | All full-screen menu screens |
| 10 | `TractionHUD` | Per-wheel grip overlay |
| 50 | `SceneManager` overlays | Modal dialogs, pause overlay |
| 100 | `GraphicsManager` / Notifications | Toast messages, tier indicator |
| 200 | `SceneManager` transitions | Fade/glitch layer — must be topmost |

**Never** create a CanvasLayer at 200 in any non-SceneManager code. Layer 200 is reserved for
transitions so they always render above all game and menu content.

### A.4 mouse_filter Modes

| Mode | Constant | Behavior |
|------|----------|---------|
| Stop | `Control.MOUSE_FILTER_STOP` | Default. Consumes all mouse events, blocks children below. |
| Pass | `Control.MOUSE_FILTER_PASS` | Receives events but also passes them through. |
| Ignore | `Control.MOUSE_FILTER_IGNORE` | Completely transparent to mouse. Use for overlay containers. |

**Project lesson (TractionHUD bug):** Any full-screen `Control` used purely as a visual overlay
**MUST** use `MOUSE_FILTER_IGNORE`. If it uses `STOP` (default), it silently blocks all mouse
events from reaching panels below it — including TuningPanel sliders and menu buttons.

```gdscript
# CORRECT: visual-only full-screen overlay
var root := Control.new()
root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # ← mandatory for visual-only overlays
add_child(root)
```

### A.5 Focus System

Focus determines which Control receives keyboard/gamepad input.

```gdscript
# FOCUS_NONE  — recommended for mouse-only controls (sliders in TuningPanel)
# FOCUS_CLICK — focus acquired on mouse click (risky: gamepad axis moves focused slider)
# FOCUS_ALL   — focus via Tab key or gamepad d-pad navigation

# Project lesson (TuningPanel): always FOCUS_NONE for HSlider to prevent
# controller steering input from adjusting last-clicked slider.
slider.focus_mode = Control.FOCUS_NONE

# For menu buttons that need gamepad nav: FOCUS_ALL + set neighbor chains
btn.focus_mode = Control.FOCUS_ALL
btn.focus_neighbor_bottom = btn.get_path_to(next_btn)
btn.focus_neighbor_top    = btn.get_path_to(prev_btn)
```

**Gamepad nav pattern** for a vertical button list:
```gdscript
func _set_focus_chain(buttons: Array[Button]) -> void:
    for i in buttons.size():
        buttons[i].focus_mode = Control.FOCUS_ALL
        if i > 0:
            buttons[i].focus_neighbor_top = buttons[i].get_path_to(buttons[i - 1])
            buttons[i - 1].focus_neighbor_bottom = buttons[i - 1].get_path_to(buttons[i])
    buttons[0].grab_focus()  # Set initial focus
```

---

## B. Theme System

### B.1 Four-Level Override Hierarchy

Godot applies theme overrides in this priority order (highest to lowest):
1. **Local overrides** — `add_theme_color_override("font_color", c)` on the node directly
2. **Node's own theme** — `node.theme = my_theme`
3. **Parent theme** — theme set on an ancestor Control node
4. **Project theme** — set in Project Settings → General → GUI → Theme → Custom Theme

Always set the project theme in `project.godot` so all controls inherit it without explicit assignment:
```
[rendering]
theme/custom="res://resources/themes/rc_theme.tres"
```

For one-off overrides, use local overrides rather than creating a whole new theme.

### B.2 Color Palette Constants

Defined in `scripts/ui/theme_constants.gd`:

```gdscript
# scripts/ui/theme_constants.gd
class_name ThemeConstants

# ── Base palette ─────────────────────────────────────────────────────────────
const BG_BLACK      := Color("#000000")  # Background / base
const TEXT_WHITE    := Color("#FFFFFF")  # Primary text, high-contrast elements
const ACCENT_CYAN   := Color("#00C8FF")  # Primary accent (buttons, borders, active)
const ACCENT_RED    := Color("#FF5154")  # Secondary accent (warnings, locked, danger)
const ACCENT_YELLOW := Color("#D7DF00")  # Tertiary accent (highlights, stats, hover glow)

# ── Derived (transparency) ───────────────────────────────────────────────────
const CYAN_25   := Color(0.0, 0.784, 1.0, 0.25)   # #00C8FF @ 25% — wireframe grids
const CYAN_50   := Color(0.0, 0.784, 1.0, 0.50)   # #00C8FF @ 50% — glowing borders
const RED_25    := Color(1.0, 0.318, 0.329, 0.25)  # #FF5154 @ 25% — locked overlays

# ── Elevated surfaces ────────────────────────────────────────────────────────
const PANEL_BG      := Color("#1a1a1a")  # Card / panel background
const PANEL_ELEVATED := Color("#111111") # Slightly elevated from pure black
const TEXT_MUTED    := Color("#333333")  # Disabled / muted text

# ── Typography sizes (pixels, 1080p base) ────────────────────────────────────
const FONT_H1      := 64  # Screen title
const FONT_H2      := 40  # Section header
const FONT_H3      := 28  # Card title
const FONT_BODY    := 20  # Normal UI text
const FONT_SMALL   := 16  # Captions, metadata
const FONT_MICRO   := 12  # Fine print, debug labels
```

### B.3 StyleBoxFlat Recipes

```gdscript
# ── Cyan-bordered panel (main content panels) ─────────────────────────────────
func make_panel_style() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color             = ThemeConstants.PANEL_BG
    s.border_width_left    = 1
    s.border_width_right   = 1
    s.border_width_top     = 1
    s.border_width_bottom  = 1
    s.border_color         = ThemeConstants.CYAN_50
    s.corner_radius_top_left     = 4
    s.corner_radius_top_right    = 4
    s.corner_radius_bottom_left  = 4
    s.corner_radius_bottom_right = 4
    return s

# ── Primary button (normal state) ────────────────────────────────────────────
func make_btn_normal() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color      = Color(0, 0, 0, 0)           # transparent fill
    s.border_width_left = s.border_width_right = 2
    s.border_width_top  = s.border_width_bottom = 2
    s.border_color  = ThemeConstants.ACCENT_CYAN
    s.corner_radius_top_left     = 2
    s.corner_radius_top_right    = 2
    s.corner_radius_bottom_left  = 2
    s.corner_radius_bottom_right = 2
    return s

# ── Primary button (hover state) ─────────────────────────────────────────────
func make_btn_hover() -> StyleBoxFlat:
    var s: StyleBoxFlat = make_btn_normal().duplicate()
    s.bg_color     = ThemeConstants.CYAN_25
    s.border_color = ThemeConstants.ACCENT_CYAN
    s.border_glow_size   = 6.0       # soft outer glow
    s.border_blend       = true
    return s

# ── Primary button (pressed state) ───────────────────────────────────────────
func make_btn_pressed() -> StyleBoxFlat:
    var s: StyleBoxFlat = make_btn_normal().duplicate()
    s.bg_color     = ThemeConstants.CYAN_50
    s.border_color = ThemeConstants.TEXT_WHITE
    return s

# ── Locked/disabled button ────────────────────────────────────────────────────
func make_btn_locked() -> StyleBoxFlat:
    var s: StyleBoxFlat = make_btn_normal().duplicate()
    s.bg_color     = ThemeConstants.RED_25
    s.border_color = ThemeConstants.ACCENT_RED
    return s

# ── Danger / CTA button (secondary accent red) ───────────────────────────────
func make_btn_danger() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color     = Color(0, 0, 0, 0)
    s.border_width_left = s.border_width_right = 2
    s.border_width_top  = s.border_width_bottom = 2
    s.border_color = ThemeConstants.ACCENT_RED
    s.corner_radius_top_left     = 2
    s.corner_radius_top_right    = 2
    s.corner_radius_bottom_left  = 2
    s.corner_radius_bottom_right = 2
    return s
```

### B.4 Typography (Theme Resource Setup)

For a `.tres` Theme, set default font sizes per control type:

```gdscript
# In code (for runtime-created themes):
var theme := Theme.new()
theme.set_font_size("font_size", "Label", ThemeConstants.FONT_BODY)
theme.set_font_size("font_size", "Button", ThemeConstants.FONT_BODY)
theme.set_color("font_color", "Label", ThemeConstants.TEXT_WHITE)
theme.set_color("font_color", "Button", ThemeConstants.TEXT_WHITE)
theme.set_color("font_pressed_color", "Button", ThemeConstants.ACCENT_CYAN)
theme.set_color("font_hover_color",   "Button", ThemeConstants.ACCENT_YELLOW)
theme.set_color("font_disabled_color","Button", ThemeConstants.TEXT_MUTED)
theme.set_stylebox("normal",   "Button", make_btn_normal())
theme.set_stylebox("hover",    "Button", make_btn_hover())
theme.set_stylebox("pressed",  "Button", make_btn_pressed())
theme.set_stylebox("disabled", "Button", make_btn_locked())
theme.set_stylebox("panel",    "PanelContainer", make_panel_style())
```

### B.5 Content Scale Mode (Responsive Scaling)

In `project.godot`, set:
```
[display]
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
window/size/viewport_width=1920
window/size/viewport_height=1080
```

This makes all UI coordinates authored at 1920×1080. Godot scales automatically to any resolution
while maintaining aspect ratio. UI will letter-box/pillar-box on non-16:9 displays.

---

## C. Scene Management & Screen Flow

### C.1 Three Approaches Compared

| Approach | How It Works | When To Use |
|----------|-------------|-------------|
| `change_scene_to_file()` | Unloads entire tree, loads new scene | Major scene transitions (menu → gameplay) |
| Manual add/remove | `add_child(screen)` / `remove_child(screen)` | Overlay stack, sub-screens within menus |
| CanvasLayer overlay | Push a CanvasLayer on top | Pause menu, modal dialogs, toast notifications |

**This project uses all three:**
- `change_scene_to_file()` for boot → menu and menu → gameplay
- Manual add/remove for sub-menu navigation within the SceneManager overlay stack
- CanvasLayer overlays for pause, dialogs, and notifications (added as children of SceneManager)

### C.2 SceneManager Autoload Pattern

```gdscript
# scripts/autoloads/scene_manager.gd
extends Node

signal screen_changed(screen_name: String)
signal overlay_pushed(overlay_name: String)
signal overlay_popped(overlay_name: String)

enum SessionState {
    IDLE,       # Before game starts
    LOADING,    # Async loading a scene
    FREE_ROAM,  # Gameplay without a formal race
    PRE_RACE,   # Pre-race setup
    RACING,     # Active race
    POST_RACE,  # Results screen
    PAUSED,     # Gameplay paused (overlay active)
}

var session_state: SessionState = SessionState.IDLE

# Internal overlay stack: Array of Control nodes
var _overlay_stack: Array[Control] = []

# CanvasLayer buckets
var _menu_layer:       CanvasLayer  # Layer 5 — main menu screens
var _overlay_layer:    CanvasLayer  # Layer 50 — pause, modals
var _transition_layer: CanvasLayer  # Layer 200 — transitions

func push_overlay(overlay: Control) -> void:
    _overlay_stack.push_back(overlay)
    _overlay_layer.add_child(overlay)
    overlay_pushed.emit(overlay.name)

func pop_overlay() -> void:
    if _overlay_stack.is_empty():
        return
    var top: Control = _overlay_stack.pop_back()
    _overlay_layer.remove_child(top)
    top.queue_free()
    overlay_popped.emit(top.name)

func pop_all_overlays() -> void:
    while not _overlay_stack.is_empty():
        pop_overlay()
```

### C.3 Fade Transitions via Tween

```gdscript
# Fade to black
func fade_out(duration: float = 0.3) -> void:
    var rect := ColorRect.new()
    rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    rect.color = Color.BLACK
    rect.color.a = 0.0
    _transition_layer.add_child(rect)
    var tween := create_tween()
    tween.tween_property(rect, "color:a", 1.0, duration)
    await tween.finished

# Fade from black (call after new screen is ready)
func fade_in(duration: float = 0.3) -> void:
    if _transition_layer.get_child_count() == 0:
        return
    var rect: ColorRect = _transition_layer.get_child(0)
    var tween := create_tween()
    tween.tween_property(rect, "color:a", 0.0, duration)
    await tween.finished
    rect.queue_free()
```

### C.4 Threaded Scene Loading

Use `ResourceLoader` with `load_threaded_request` for the loading screen:

```gdscript
# Start loading (non-blocking)
ResourceLoader.load_threaded_request("res://scenes/main.tscn")

# In _process on the loading screen:
func _process(_delta: float) -> void:
    var progress := []
    var status := ResourceLoader.load_threaded_get_status("res://scenes/main.tscn", progress)
    match status:
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            _progress_bar.value = progress[0] * 100.0
        ResourceLoader.THREAD_LOAD_LOADED:
            _on_scene_loaded()
        ResourceLoader.THREAD_LOAD_FAILED:
            push_error("Scene load failed")

func _on_scene_loaded() -> void:
    var packed: PackedScene = ResourceLoader.load_threaded_get("res://scenes/main.tscn")
    SceneManager.transition_to_gameplay(packed)
```

---

## D. Menu Patterns

### D.1 Splash Screen

Two variants:
- **Static**: Full-screen `ColorRect` background with title label + pulse animation.
- **Live 3D** (project target): `SubViewportContainer` + `SubViewport` showing car scene.

```gdscript
# Live 3D splash background setup
var container := SubViewportContainer.new()
container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
container.stretch = true
var viewport := SubViewport.new()
viewport.size = Vector2i(1920, 1080)
viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
container.add_child(viewport)
# Load and instance the 3D scene into viewport
var scene: PackedScene = load("res://scenes/tracks/test_track.tscn")
viewport.add_child(scene.instantiate())
add_child(container)
```

**Press Start detection** (any key or gamepad button):
```gdscript
func _input(event: InputEvent) -> void:
    if not _ready_to_advance:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        SceneManager.go_to_main_menu()
    elif event is InputEventJoypadButton and event.pressed:
        SceneManager.go_to_main_menu()
```

**Pulse animation** for "Press Start":
```gdscript
func _animate_press_start(label: Label) -> void:
    var tween := create_tween().set_loops()
    tween.tween_property(label, "modulate:a", 0.1, 0.8)
    tween.tween_property(label, "modulate:a", 1.0, 0.8)
```

### D.2 Main Menu with Staggered Animations

```gdscript
func _animate_in() -> void:
    var buttons: Array = _button_container.get_children()
    for i in buttons.size():
        var btn: Control = buttons[i]
        btn.modulate.a = 0.0
        btn.position.x = -80.0  # start offset left
        var tween := create_tween()
        tween.set_delay(i * 0.08)  # stagger by 80ms each
        tween.tween_property(btn, "modulate:a", 1.0, 0.25)
        tween.parallel().tween_property(btn, "position:x", 0.0, 0.25) \
            .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
```

### D.3 Sub-Menu Back Stack

SceneManager maintains a navigation history stack:
```gdscript
var _nav_stack: Array[String] = []  # e.g. ["main_menu", "mode_select"]

func navigate_to(screen_name: String) -> void:
    _nav_stack.push_back(screen_name)
    _show_screen(screen_name)

func navigate_back() -> void:
    if _nav_stack.size() <= 1:
        return
    _nav_stack.pop_back()
    _show_screen(_nav_stack.back())
```

**Escape/B-button** always calls `navigate_back()` in menu context, never `quit()`.

### D.4 Modal Dialogs

```gdscript
# Dimmed backdrop + centered dialog box
func show_modal(title: String, message: String, options: Array[String]) -> Signal:
    var backdrop := ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0, 0, 0, 0.7)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks behind

    var dialog := PanelContainer.new()
    dialog.custom_minimum_size = Vector2(500, 250)
    # ... add title, message, buttons
    SceneManager.push_overlay(backdrop)
    return _choice_signal  # returns signal that emits chosen option string
```

### D.5 Tab-Based Settings / Options Menu

```gdscript
# Four tabs: Video / Audio / Controls / Gameplay
var tabs := TabContainer.new()
tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Each tab is a VBoxContainer added as a child
var video_tab := VBoxContainer.new()
video_tab.name = "Video"  # ← Tab label comes from child's name
tabs.add_child(video_tab)
```

For gamepad navigation within tabs, use `TabContainer.current_tab` property and intercept
`ui_left`/`ui_right` actions to switch tabs.

### D.6 Car/Track Carousel with SubViewport Preview

```gdscript
# Carousel: left arrow | preview area | right arrow
var carousel := HBoxContainer.new()
var prev_btn := Button.new(); prev_btn.text = "<"
var next_btn := Button.new(); next_btn.text = ">"
var viewport_container := SubViewportContainer.new()
viewport_container.stretch = true
viewport_container.custom_minimum_size = Vector2(640, 360)

var preview_viewport := SubViewport.new()
preview_viewport.size = Vector2i(640, 360)
preview_viewport.own_world_3d = true  # ← isolated 3D world for preview
preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

var car_scene: PackedScene = load("res://scenes/cars/rc_buggy.tscn")
var car_instance := car_scene.instantiate()
preview_viewport.add_child(car_instance)
```

**own_world_3d = true** is critical: without it, the preview SubViewport shares the main world,
causing camera/lighting conflicts.

### D.7 Locked Mode Presentation

```gdscript
func _present_locked_mode(card: PanelContainer) -> void:
    # Semi-transparent red overlay
    var lock_overlay := ColorRect.new()
    lock_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    lock_overlay.color = ThemeConstants.RED_25
    card.add_child(lock_overlay)

    # Lock icon label (using font emoji or icon texture)
    var lock_label := Label.new()
    lock_label.text = "🔒 COMING SOON"
    lock_label.add_theme_color_override("font_color", ThemeConstants.ACCENT_RED)
    lock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    card.add_child(lock_label)

    # Make non-interactive
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

---

## E. Animation & Polish

### E.1 Tween Helper Library

Common reusable Tween patterns (put in `SceneManager` or a static utility):

```gdscript
# Slide in from left
static func slide_in_from_left(node: Control, duration: float = 0.3) -> Tween:
    node.position.x -= 200.0
    node.modulate.a  = 0.0
    var t := node.create_tween()
    t.set_parallel(true)
    t.tween_property(node, "position:x", node.position.x + 200.0, duration) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    t.tween_property(node, "modulate:a", 1.0, duration * 0.5)
    return t

# Fade in
static func fade_in(node: Control, duration: float = 0.25) -> Tween:
    node.modulate.a = 0.0
    var t := node.create_tween()
    t.tween_property(node, "modulate:a", 1.0, duration)
    return t

# Stagger children fade in
static func stagger_children_in(parent: Control, delay: float = 0.06,
        duration: float = 0.2) -> void:
    var children := parent.get_children()
    for i in children.size():
        var child := children[i] as Control
        if child == null:
            continue
        child.modulate.a = 0.0
        var t := child.create_tween()
        t.set_delay(i * delay)
        t.tween_property(child, "modulate:a", 1.0, duration)

# Pulse (loop)
static func pulse(node: Control, min_alpha: float = 0.2,
        period: float = 1.6) -> Tween:
    var t := node.create_tween().set_loops()
    t.tween_property(node, "modulate:a", min_alpha, period * 0.5) \
        .set_ease(Tween.EASE_IN_OUT)
    t.tween_property(node, "modulate:a", 1.0, period * 0.5) \
        .set_ease(Tween.EASE_IN_OUT)
    return t
```

### E.2 Hover/Focus/Press StyleBox States

Button StyleBox states map to these theme keys:
- `"normal"` — default unpressed, unfocused
- `"hover"` — mouse over
- `"pressed"` — currently clicked
- `"focus"` — keyboard/gamepad focus (separate from hover)
- `"disabled"` — button.disabled = true

```gdscript
# Apply all states to a Button
func apply_primary_style(btn: Button) -> void:
    btn.add_theme_stylebox_override("normal",   _btn_normal)
    btn.add_theme_stylebox_override("hover",    _btn_hover)
    btn.add_theme_stylebox_override("pressed",  _btn_pressed)
    btn.add_theme_stylebox_override("focus",    _btn_focus)   # yellow glow ring
    btn.add_theme_stylebox_override("disabled", _btn_locked)
    btn.add_theme_color_override("font_color",         ThemeConstants.TEXT_WHITE)
    btn.add_theme_color_override("font_hover_color",   ThemeConstants.ACCENT_YELLOW)
    btn.add_theme_color_override("font_pressed_color", ThemeConstants.ACCENT_CYAN)
    btn.add_theme_font_size_override("font_size",      ThemeConstants.FONT_BODY)

# Focus StyleBox: yellow outer border
func make_btn_focus() -> StyleBoxFlat:
    var s: StyleBoxFlat = make_btn_normal().duplicate()
    s.border_color = ThemeConstants.ACCENT_YELLOW
    s.border_width_left = s.border_width_right = 3
    s.border_width_top  = s.border_width_bottom = 3
    return s
```

### E.3 Glitch / Scan-Line Transition Recipes

**Transition philosophy**: Brief (0.3–0.5s), technical/digital aesthetic. Never slow.

#### E.3.1 Horizontal Scan-Line Wipe (GDScript + Shader)

Create a `ColorRect` in the transition layer with a custom shader:

```glsl
// res://resources/shaders/scanline_wipe.gdshader
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float noise_strength : hint_range(0.0, 0.05) = 0.01;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    // Scan-line wipe: pixels above progress line show black, below show through
    float y_threshold = 1.0 - progress;
    // Pixel displacement noise in the wipe boundary region
    float boundary_dist = abs(UV.y - y_threshold);
    float displacement = 0.0;
    if (boundary_dist < 0.05) {
        displacement = (rand(vec2(UV.y, TIME)) * 2.0 - 1.0) * noise_strength
                     * (1.0 - boundary_dist / 0.05);
    }
    vec2 displaced_uv = UV + vec2(displacement, 0.0);
    if (UV.y < y_threshold) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);  // black wipe
    } else {
        COLOR = texture(screen_texture, displaced_uv);
    }
}
```

```gdscript
# Perform a scanline wipe transition (SceneManager)
func _do_scanline_wipe(duration: float = 0.4) -> void:
    var rect := ColorRect.new()
    rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var mat := ShaderMaterial.new()
    mat.shader = preload("res://resources/shaders/scanline_wipe.gdshader")
    rect.material = mat
    _transition_layer.add_child(rect)
    var tween := create_tween()
    tween.tween_method(
        func(v: float) -> void: mat.set_shader_parameter("progress", v),
        0.0, 1.0, duration
    )
    await tween.finished
    rect.queue_free()
```

#### E.3.2 Digital Noise Flash (Overlay Transitions)

For lighter transitions (e.g., pausing):

```gdscript
func _do_noise_flash(layer: CanvasLayer, duration: float = 0.15) -> void:
    var rect := ColorRect.new()
    rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # Cyan flash at low alpha — "boot up" flicker
    rect.color = Color(ThemeConstants.ACCENT_CYAN, 0.0)
    layer.add_child(rect)
    var tween := create_tween()
    tween.tween_property(rect, "color:a", 0.15, duration * 0.3)
    tween.tween_property(rect, "color:a", 0.0,  duration * 0.7)
    await tween.finished
    rect.queue_free()
```

#### E.3.3 Wireframe Grid Sweep

Animated grid using a second shader (for splash screen background reveal):

```glsl
// res://resources/shaders/grid_sweep.gdshader
shader_type canvas_item;
uniform float sweep_progress : hint_range(0.0, 1.0) = 0.0;
uniform float grid_scale : hint_range(10.0, 200.0) = 60.0;
uniform vec4 grid_color : source_color = vec4(0.0, 0.784, 1.0, 0.25);

void fragment() {
    vec2 grid_uv = UV * grid_scale;
    float line_x = step(0.97, fract(grid_uv.x));
    float line_y = step(0.97, fract(grid_uv.y));
    float grid = clamp(line_x + line_y, 0.0, 1.0);
    // Sweep: reveal from left, trailing edge with fade
    float reveal = smoothstep(sweep_progress - 0.15, sweep_progress, UV.x);
    COLOR = grid_color * grid * reveal;
}
```

### E.4 Staggered Element Entrance Timing

Rule of thumb for staggered menus:
- Title / logo: appears first (0ms delay)
- Nav bar / breadcrumb: 50ms delay
- Main buttons: 80ms between each button
- Stat bars / secondary info: 150ms after buttons

```gdscript
# In BaseMenuScreen._animate_in() — override in each screen
func _animate_in() -> void:
    if _title_label:
        TweenHelper.fade_in(_title_label, 0.2)
    if _nav_bar:
        var t := TweenHelper.fade_in(_nav_bar, 0.2)
        t.set_delay(0.05)
    TweenHelper.stagger_children_in(_button_container, 0.08, 0.2)
```

---

## F. Input Handling for Menus

### F.1 Built-in ui_* Actions

Godot provides these built-in input actions (always available, no project config needed):

| Action | Default Binding | Menu Use |
|--------|----------------|---------|
| `ui_accept` | Enter, Space, Joypad A | Confirm / select focused button |
| `ui_cancel` | Escape, Joypad B | Back / cancel / close |
| `ui_up` / `ui_down` | Arrow keys, D-pad | Move focus vertically |
| `ui_left` / `ui_right` | Arrow keys, D-pad | Move focus horizontally / cycle tabs |
| `ui_focus_next` | Tab | Move focus to next control |
| `ui_focus_prev` | Shift+Tab | Move focus to previous control |
| `ui_home` / `ui_end` | Home/End | Jump to first/last item |

**Important**: `Button` nodes automatically respond to `ui_accept` when focused — no manual `_input()` needed for keyboard/gamepad button activation.

### F.2 Focus-Based Gamepad Nav Setup

```gdscript
# ── Vertical list (Main Menu) ─────────────────────────────────────────────────
func _setup_focus_chain_vertical(buttons: Array[Button]) -> void:
    for i in buttons.size():
        var b: Button = buttons[i]
        b.focus_mode = Control.FOCUS_ALL
        if i > 0:
            b.focus_neighbor_top = b.get_path_to(buttons[i - 1])
            buttons[i - 1].focus_neighbor_bottom = buttons[i - 1].get_path_to(b)
    # Wrap: last → first
    buttons[-1].focus_neighbor_bottom = buttons[-1].get_path_to(buttons[0])
    buttons[0].focus_neighbor_top     = buttons[0].get_path_to(buttons[-1])
    if buttons.size() > 0:
        buttons[0].grab_focus()

# ── Grid (Mode Select — 4 cards) ──────────────────────────────────────────────
func _setup_focus_grid(cards: Array[Button], cols: int) -> void:
    for i in cards.size():
        var c: Button = cards[i]
        c.focus_mode = Control.FOCUS_ALL
        if i >= cols:
            c.focus_neighbor_top    = c.get_path_to(cards[i - cols])
            cards[i - cols].focus_neighbor_bottom = cards[i - cols].get_path_to(c)
        if i % cols != 0:
            c.focus_neighbor_left  = c.get_path_to(cards[i - 1])
            cards[i - 1].focus_neighbor_right = cards[i - 1].get_path_to(c)
    if cards.size() > 0:
        cards[0].grab_focus()
```

### F.3 Input Device Detection (Keyboard vs Gamepad Prompt Switching)

```gdscript
# Detect which device the player last used, update prompts
var _last_input_device: String = "keyboard"

func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        if _last_input_device != "gamepad":
            _last_input_device = "gamepad"
            _update_prompts()
    elif event is InputEventKey or event is InputEventMouseButton:
        if _last_input_device != "keyboard":
            _last_input_device = "keyboard"
            _update_prompts()

func _update_prompts() -> void:
    # Update "Press [Enter] / [A]" labels based on device
    if _last_input_device == "gamepad":
        _press_start_label.text = "Press [A] to Start"
    else:
        _press_start_label.text = "Press [Enter] to Start"
```

### F.4 Preventing Input Leaks Between Menu and Gameplay

```gdscript
# In SceneManager: block game input while in menu
func _set_gameplay_input_enabled(enabled: bool) -> void:
    InputManager.set_active(enabled)
    # Also block GameManager pause action to avoid Escape conflicts
    GameManager.menu_active = not enabled

# In game_manager.gd: check menu_active before handling Escape
func _input(event: InputEvent) -> void:
    if menu_active:
        return  # Let SceneManager handle Escape in menu context
    if event.is_action_pressed("quit"):
        SceneManager.request_quit()  # Let SceneManager handle, not quit() directly
        return
    if event.is_action_pressed("pause"):
        SceneManager.toggle_pause()
```

### F.5 process_mode for Pause Menu

Pause menus need `PROCESS_MODE_ALWAYS` so they receive input/process while `get_tree().paused = true`.

```gdscript
# In pause_menu.gd
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS  # Must run while tree is paused
    # Gameplay is paused by SceneManager setting get_tree().paused = true
    # The pause overlay must NOT be paused itself
```

**All menu CanvasLayers** should have `process_mode = PROCESS_MODE_ALWAYS` so transitions
and menu input continue working when gameplay is paused.

---

## G. Seamless Session Management

### G.1 SessionState Enum & Transitions

```
IDLE ──→ LOADING ──→ FREE_ROAM ──→ PRE_RACE ──→ RACING ──→ POST_RACE
                                                    ↕
                                                  PAUSED
```

Valid transitions:
| From | To | Trigger |
|------|----|---------|
| IDLE | LOADING | Player chooses to play |
| LOADING | FREE_ROAM | Scene loaded (Testing mode) |
| LOADING | PRE_RACE | Scene loaded (Race mode) |
| FREE_ROAM | PAUSED | Escape key |
| RACING | PAUSED | Escape key |
| PAUSED | FREE_ROAM / RACING | Resume |
| PAUSED | IDLE | Return to menu |
| RACING | POST_RACE | Race finished |
| POST_RACE | IDLE | Return to menu |

### G.2 Overlay vs Scene-Change Decision Matrix

| Action | Method | Why |
|--------|--------|-----|
| Open pause menu | Push overlay (layer 50) | Gameplay stays alive beneath |
| Open options from main menu | Push overlay (layer 50) | Main menu stays beneath |
| Return to main menu from pause | Pop overlays → change_scene | Clean slate |
| Enter gameplay | change_scene_to_file() | Full scene swap |
| Show modal confirm dialog | Push overlay (layer 50) | Temporary, blocks input |
| Show toast notification | Add to layer 100 (timed) | Non-blocking, auto-dismiss |
| Show loading screen | change_scene_to_file() to loading screen | Loading progress needs full frame |

### G.3 Mode Switching Architecture

Modes available at launch:
- **Testing** (unlocked): Free roam on test track. Uses existing `scenes/main.tscn`.
- **Time Attack** (locked — placeholder): Lap timer against ghost.
- **Tournament** (locked — placeholder): Bracket mode.
- **Multiplayer** (locked — placeholder): LAN/online.

Mode data structure:
```gdscript
# In SceneManager or GameManager
const MODES: Array[Dictionary] = [
    {
        "id": "testing",
        "title": "Testing",
        "description": "Free roam on the test track. No pressure.",
        "scene": "res://scenes/main.tscn",
        "locked": false,
        "icon": "res://resources/icons/mode_testing.svg",
    },
    {
        "id": "time_attack",
        "title": "Time Attack",
        "description": "Beat your best lap time.",
        "scene": "",   # not yet implemented
        "locked": true,
    },
    # ...
]
```

### G.4 Notification/Toast System

```gdscript
# In SceneManager (or a dedicated ToastManager)
func show_toast(message: String, duration: float = 3.0,
        color: Color = ThemeConstants.ACCENT_CYAN) -> void:
    var label := Label.new()
    label.text = message
    label.add_theme_color_override("font_color", color)
    label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
    label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    label.offset_top = -80.0
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.modulate.a = 0.0
    _notification_layer.add_child(label)

    var tween := create_tween()
    tween.tween_property(label, "modulate:a", 1.0, 0.3)
    tween.tween_interval(duration - 0.6)
    tween.tween_property(label, "modulate:a", 0.0, 0.3)
    await tween.finished
    label.queue_free()
```

---

## H. Performance

### H.1 Avoid Per-Frame Allocations

```gdscript
# BAD: creates new StyleBoxFlat every frame
func _process(_delta: float) -> void:
    var s := StyleBoxFlat.new()
    s.bg_color = _current_color
    _panel.add_theme_stylebox_override("panel", s)

# GOOD: create once, mutate
var _panel_style: StyleBoxFlat

func _ready() -> void:
    _panel_style = StyleBoxFlat.new()
    _panel.add_theme_stylebox_override("panel", _panel_style)

func _process(_delta: float) -> void:
    _panel_style.bg_color = _current_color  # mutate in place
```

### H.2 MSDF Font Imports

For technical/monospace fonts:
- Import as **MSDF** (Multi-channel SDF) for crisp rendering at any size.
- In the `.import` file / import dock: set `subpixel_positioning=0`, `msdf_mode=true`.
- MSDF fonts remain sharp when scaled up/down — important for responsive UI.

```
[params]
compress/mode=3
subpixel_positioning=0
msdf_pixel_range=8
msdf_size=48
```

### H.3 Example Font Stack

**Chosen fonts** (both SIL OFL 1.1 — free for commercial use, download from Google Fonts):

| Font | File | Weight | Role |
|------|------|--------|------|
| **Rajdhani** | `Rajdhani-Bold.ttf` | Bold 700 | Screen titles, game logo (FONT_H1/H2) |
| **Rajdhani** | `Rajdhani-SemiBold.ttf` | SemiBold 600 | Buttons, card titles, body text (default) |
| **Rajdhani** | `Rajdhani-Regular.ttf` | Regular 400 | Captions, metadata, nav crumbs (FONT_SMALL/MICRO) |
| **Source Code Pro** | `SourceCodePro-Regular.ttf` | Regular | HUD speed/time values, loading %, telemetry |

**Why Rajdhani:**
- Geometric, narrow-proportion sans → designed for technical/engineering display contexts
- All-caps ("SELECT MODE", "GAME TITLE") reads as intentional design, not laziness
- Used in motorsport HUDs, F1 graphics, automotive dashboards — works well for technical/precision themes
- The #00C8FF cyan at Bold weight creates strong visual hierarchy against the black background
- Narrow proportions fit long button labels like "RETURN TO MENU" without wrapping

**Why Source Code Pro:**
- Adobe's professional open-source monospace — clean, highly legible, excellent digit clarity
- Monospaced: changing values (001 → 112 → 999 km/h) never cause layout jitter
- Wide weight range (ExtraLight–Black) available if heavier telemetry labels are ever needed
- Pairs naturally with Rajdhani: both are geometric and screen-optimised

**Install procedure:**
1. Download `Rajdhani` family (get Regular, SemiBold, Bold weights) and `Source Code Pro`
2. Place the four `.ttf` files in `res://resources/fonts/`
3. In Godot Editor: select each `.ttf` → Import tab → enable **Multichannel Signed Distance Field**
4. Set `msdf_pixel_range = 8`, `msdf_size = 48` → click **Reimport**
5. Fonts activate automatically (ThemeConstants lazy-loads them on first access)

**Code pattern** (ThemeConstants provides the font, BaseMenuScreen provides the helpers):
```gdscript
# Apply in _build_ui() after creating the label:
_apply_font_bold(title_lbl)       # → Rajdhani Bold
_apply_font_reg(version_lbl)      # → Rajdhani Regular
_apply_font_mono(speed_lbl)       # → Source Code Pro

# In components (StatBar, NavBar) that don't extend BaseMenuScreen — call directly:
var f := ThemeConstants.get_font_ui_reg()
if f:
    label.add_theme_font_override("font", f)
```

**Weight usage guide:**
- `Bold` → screen titles only (SELECT MODE, PAUSED, LOADING, PRE-RACE SETUP, game logo)
- `SemiBold` → everything interactive: buttons, card titles, stat bar values, carousel names
- `Regular` → secondary text: captions, metadata, nav crumbs, version string, descriptions, surface labels
- `Mono` → any live numeric data that updates at runtime (speed, lap time, loading %)

### H.3 Lazy Screen Instantiation

Don't instantiate all menu screens at startup. Load on first visit:

```gdscript
var _screen_cache: Dictionary = {}  # screen_name → Control node

func _get_or_create_screen(screen_name: String) -> Control:
    if screen_name in _screen_cache:
        return _screen_cache[screen_name]
    var path: String = SCREEN_PATHS[screen_name]
    var packed: PackedScene = load(path)
    var screen: Control = packed.instantiate()
    _screen_cache[screen_name] = screen
    return screen
```

Cache screens that are frequently revisited (main menu, options). Free screens that are visited once
(splash, loading) to reclaim memory.

### H.4 Draw Call Awareness

- Each `CanvasItem` with a unique `material` = extra draw call. Keep shader materials minimal.
- Use `CanvasGroup` node to batch multiple Control nodes into a single draw call when possible.
- Prefer Label over multiple single-character Labels for text.
- `SubViewport` always costs a full render pass — limit to 1 active preview at a time.

---

## I. Project Integration Notes

### I.1 Existing Autoloads

| Autoload | Singleton Name | Integration Point |
|----------|---------------|------------------|
| `game_manager.gd` | `GameManager` | Pause, quit, game state. Must defer Escape/quit to SceneManager in menu context. |
| `race_manager.gd` | `RaceManager` | `start_race()`, lap timing. Called by main.gd after gameplay loads. |
| `input_manager.gd` | `InputManager` | `get_throttle()`, `get_steer()` etc. Must be disabled while in menus. |
| `graphics_manager.gd` | `GraphicsManager` | `apply_tier(tier)`. Wired to Options menu Video tab. Uses CanvasLayer 100 for its notification — no conflict. |
| `scene_manager.gd` | `SceneManager` | **New.** Owns all screen navigation, transition effects, overlay stack. |

### I.2 Existing Code Conventions (Must Match)

From `.ai/knowledge/architecture/coding-standards.gd`:

```gdscript
# ── Typing ────────────────────────────────────────────────────────────────────
# All vars typed. No untyped params. Typed arrays: Array[Button] not Array.
var _buttons: Array[Button] = []

# ── Naming ────────────────────────────────────────────────────────────────────
# Private vars/methods: _underscore prefix
# Signals: snake_case, past tense (screen_changed, option_applied)
# Enums: PascalCase type, UPPER_CASE values

# ── @onready vs _ready assignment ─────────────────────────────────────────────
# Prefer @onready for scene-tree nodes. Use _ready() for logic init.
@onready var _btn_play: Button = $VBox/BtnPlay

# ── No bare log() ─────────────────────────────────────────────────────────────
# CarLogger.log() is fine. log(float) is the built-in math function — name clash.
# Use push_warning() / push_error() / print() in autoloads.

# ── set_car() / set_terrain() DI pattern ─────────────────────────────────────
# New systems receive references via setter, not _ready() constructor args.
# SceneManager: pass gameplay scene ref via set_gameplay_scene(scene: Node)
```

### I.3 CanvasLayer Conflict Avoidance

Existing CanvasLayer assignments in the codebase:
- HUD: layer 1 (hardcoded in hud.gd / main.tscn)
- TuningPanel: no explicit layer (default 0 — floats above 3D but below CanvasLayer nodes)
- TractionHUD: layer 10 (hardcoded in traction_hud.gd)
- GraphicsManager notification: layer 100

**New SceneManager layers** (5, 50, 200) do not conflict with any existing layer.
The pause overlay (layer 50) correctly appears above all HUD elements (layer 1, 10).

When gameplay is running and menus are not shown, SceneManager's CanvasLayers should be
invisible (`layer_node.visible = false`) to avoid any UI element accidentally appearing.

### I.4 GameManager Integration (Pause Conflict)

Current `game_manager.gd._input()` calls `toggle_pause()` on Escape key. This conflicts with
menu navigation (Escape = back in menus, not pause).

**Solution**: Add a `menu_active: bool` flag to `GameManager`. When `menu_active = true`,
`GameManager._input()` returns early without handling Escape/pause. SceneManager sets this flag.

```gdscript
# game_manager.gd additions
var menu_active: bool = false

func _input(event: InputEvent) -> void:
    if menu_active:
        return  # SceneManager owns Escape in menu context
    if event.is_action_pressed("quit"):
        SceneManager.request_quit()
        return
    if event.is_action_pressed("pause"):
        SceneManager.toggle_pause()
```

### I.5 GraphicsManager Re-initialization After Scene Load

GraphicsManager uses `get_tree().node_added` signal to detect when `WorldEnvironment` and
`DirectionalLight3D` enter the tree. When returning to menu and re-entering gameplay:

1. The `node_added` hook disconnects itself after first initialization.
2. On re-entering gameplay, `WorldEnvironment` enters tree again but hook is gone.

**Fix**: Don't disconnect `node_added` — instead reset `_environment` and `_light` to null when
the gameplay scene is unloaded, and reconnect the signal:

```gdscript
# In GraphicsManager: called by SceneManager when gameplay unloads
func reset_for_new_scene() -> void:
    _environment = null
    _light = null
    if not get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.connect(_on_node_added)
```

### I.6 main.gd Teardown

When the player returns to menu from gameplay, `main.gd` must clean up. Add:

```gdscript
# scripts/main.gd
func teardown() -> void:
    RaceManager.end_race()
    # Disconnect any signals this scene emitted to autoloads
    if rc_buggy.is_connected("some_signal", GameManager._handler):
        rc_buggy.disconnect("some_signal", GameManager._handler)
    # Null out autoload references (good hygiene before queue_free)
    hud.set_car(null)
    tuning_panel.set_car(null)
    traction_hud.set_car(null)
    # SceneManager calls queue_free() on this scene after teardown()
```

---

*End of SKILL.md — See COMPONENTS.md for reusable component specs, MENU-FLOW.md for project screen flow.*
