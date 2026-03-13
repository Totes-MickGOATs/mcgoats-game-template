# System Manifests

System manifests declare which files belong to which game system. Every game system should have a manifest file here.

## Format

Manifests can be JSON (engine-agnostic) or `.tres` (Godot-specific).

### JSON Format (Recommended)

```json
{
  "name": "system_name",
  "description": "What this system does",
  "status": "ACTIVE",
  "files": [
    "scripts/systems/my_system.gd",
    "scenes/my_system.tscn"
  ],
  "dependencies": ["other_system"],
  "replaced_by": ""
}
```

### Status Values

| Status | Meaning |
|--------|---------|
| `ACTIVE` | In use, maintained |
| `DEPRECATED` | Replaced, do not modify |
| `EXPERIMENTAL` | WIP, not integrated |

## Validation

Run `just validate-registry` to check all manifests are valid and all declared files exist.
