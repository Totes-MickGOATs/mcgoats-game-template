# tests/

Unity Test Framework tests. Edit Mode tests for pure logic, Play Mode for runtime behavior.

## Structure

```
tests/
├── EditMode/           # Fast tests: pure C#, ScriptableObjects, serialization
│   ├── Game.Tests.EditMode.asmdef
│   └── Test_*.cs
├── PlayMode/           # Runtime tests: MonoBehaviours, physics, coroutines
│   ├── Game.Tests.PlayMode.asmdef
│   └── Test_*.cs
└── helpers/            # Shared test utilities
```

## Conventions

- **TDD:** Write test → RED → Implement → GREEN → Refactor → Commit
- **Naming:** `Test_<SystemName>.cs`, methods: `MethodName_Condition_ExpectedResult()`
- **Edit Mode first:** If it doesn't need MonoBehaviour lifecycle, use Edit Mode (10x faster)
- **[UnityTest]:** Only for tests that need coroutines (physics, scene loading, async)

## Relevant Skills

- `.agents/skills/unity-testing-patterns/SKILL.md` — Full testing guide
