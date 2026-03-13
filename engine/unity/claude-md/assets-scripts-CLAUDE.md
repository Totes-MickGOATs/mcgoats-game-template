# Assets/Scripts/

Game scripts organized by system. Each subdirectory groups related functionality.

## Conventions

- **Namespaces:** Every script must declare a namespace matching its folder path (e.g., `Game.Vehicle`)
- **One class per file:** File name matches class name (PascalCase)
- **MonoBehaviour:** Only for components that need Unity lifecycle. Pure C# classes for logic
- **[SerializeField]:** Prefer over public fields for inspector exposure
- **Assembly definitions:** Each major system should have its own .asmdef

## Relevant Skills

- `.agents/skills/unity-csharp-mastery/SKILL.md` — C# patterns and conventions
- `.agents/skills/unity-composition/SKILL.md` — Component architecture
- `.agents/skills/unity-testing-patterns/SKILL.md` — TDD with Unity Test Framework
