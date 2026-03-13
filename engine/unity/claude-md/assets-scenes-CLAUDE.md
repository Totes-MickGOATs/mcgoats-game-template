# Assets/Scenes/

Unity scenes (.unity files). Scenes are binary-ish YAML — always use Force Text serialization.

## Conventions

- **One gameplay scene + additive scenes** for managers, UI, etc.
- **Scene bootstrapper pattern:** A persistent "Boot" scene loads first, then loads gameplay additively
- **Prefabs over scene objects:** Prefer prefab instances for anything reusable
- Never edit the same scene in parallel branches — merge conflicts are painful

## Relevant Skills

- `.agents/skills/unity-scene-management/SKILL.md` — Scene loading patterns
- `.agents/skills/unity-3d-world-building/SKILL.md` — World building tools
