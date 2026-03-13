# Coding Standards

> **Template:** Customize this file for your project's specific conventions.

## General Principles

- **DRY** — Don't Repeat Yourself. Extract helpers at 3+ instances of the same pattern.
- **YAGNI** — You Aren't Gonna Need It. Don't over-engineer for hypothetical futures.
- **Signal Up, Call Down** — Autoloads/singletons emit signals; children call methods on parents.
- **Composition over inheritance** — Prefer component nodes over deep class hierarchies.

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type: short description

Optional longer body explaining why, not what.
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`, `style`

## Value Mutability Tiers

| Tier | Mechanism | When to Use |
|------|-----------|-------------|
| **Const** | `const` / class constant | Algorithm logic, physics math, IDs — never changes at runtime |
| **Export** | Engine-specific export | Per-instance tuning in editor — varies between scenes/nodes |
| **Settings** | Settings manager | User preferences persisted to config file |
| **Dynamic** | Runtime variable | Computed or changed every frame/event |

## Testing

- TDD is mandatory: Red-Green-Commit cycle
- Unit tests for logic, integration tests for wiring
- Never claim "fixed" without running the test
- Mirror magic numbers as named constants in tests

## Documentation

- Every directory has a `CLAUDE.md`
- Update docs in the same commit as code changes
- Skills in `.agents/skills/` are lazy-loaded — reference, don't duplicate
