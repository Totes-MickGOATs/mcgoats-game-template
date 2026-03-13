# scripts/

All GDScript source files. Organized by subsystem.

## Conventions

- **Forward = -Z** throughout all physics code
- Use `InputManager` for input — never read `Input` directly in gameplay code
- `Debug.log(tag, msg)` — never bare `print()` (exception: `@tool` scripts)

## Relevant Skills

- `.agents/skills/godot-gdscript-mastery/SKILL.md` — GDScript style, type safety, performance
- `.agents/skills/godot-gdscript-patterns/SKILL.md` — common GDScript patterns
- `.agents/skills/godot-signal-architecture/SKILL.md` — signal patterns, event bus
