# effects/

Visual and audio effects scripts.

## Categories

| Category | Scripts | Description |
|----------|---------|-------------|
<!-- Add your effects here -->

## Conventions

- Effects are children of the object they affect (vehicle, environment, etc.)
- GPUParticles3D preferred over CPUParticles3D for performance
- LOD: reduce particle count and effect quality at distance
- Pool and reuse effect nodes where possible

## Relevant Skills

- `.agents/skills/godot-particles/SKILL.md`
- `.agents/skills/godot-shaders-basics/SKILL.md`
