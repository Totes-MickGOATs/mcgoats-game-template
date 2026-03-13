# engine/godot/hooks/

Godot-specific hook scripts copied to `.claude/hooks/` and `.githooks/` by setup-engine.sh.

## Files

| File | Role |
|------|------|
| `pre-commit-engine.sh` | GDScript lint + parse check on staged .gd files |
| `lint-on-save-engine.sh` | gdlint + gdformat --check on saved .gd files |
| `worktree-setup-engine.sh` | Seed .godot/imported cache via `just seed-import` |
