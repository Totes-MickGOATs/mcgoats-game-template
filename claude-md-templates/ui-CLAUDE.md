# ui/

User interface scripts and scenes.

## Conventions

- FOCUS_NONE on all HSliders (prevents gamepad axis interference)
- MOUSE_FILTER_IGNORE on visual-only full-screen overlays
- All menu CanvasLayers: PROCESS_MODE_ALWAYS
- stretch/aspect = "expand" (never "keep")
- Use UIFactory for themed UI components
- Use MenuControlFactory for menu-specific controls

## Relevant Skills

- `.agents/skills/godot-frontend-design/SKILL.md`
- `.agents/skills/godot-ui-theming/SKILL.md`
- `.agents/skills/godot-ui-containers/SKILL.md`
