# autoloads/

Global singleton scripts loaded via Project Settings -> Autoload.

## Autoloads

| Autoload | Class | Role |
|----------|-------|------|
<!-- Add your autoloads here -->

## Conventions

- Signal Up, Call Down -- autoloads emit signals; children call methods on parents
- Never access other autoloads in `_ready()` -- use `_enter_tree()` or deferred calls for ordering
- All public state changes should emit a signal
- Use `Debug.log(tag, msg)` for logging, never bare `print()`

## Relevant Skills

- `.agents/skills/godot-autoload-architecture/SKILL.md`
- `.agents/skills/godot-signal-architecture/SKILL.md`
