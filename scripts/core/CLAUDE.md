# core/

Project registry system: system manifests, project registry, and shared utilities.

## System Registry

Every game system must have a manifest in `resources/manifests/`.
The registry validates file ownership, detects orphans, and tracks system dependencies.

## Files

| File | Role |
|------|------|
| (Add your core scripts here) |

## How It Works

1. Each system declares its owned files in a JSON manifest
2. `validate_registry.py` checks all manifests against disk
3. CI runs validation on every PR
4. Boot-time validation catches drift early

## Creating a New System

Use `/dev:add-system` command or manually:
1. Create `resources/manifests/<system>.json`
2. List all files owned by the system
3. Set status (ACTIVE, EXPERIMENTAL, DEPRECATED)
4. Run `just validate-registry` to verify
