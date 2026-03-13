---
description: Scaffold a new game system with manifest, directory, CLAUDE.md, and stub test
---

Scaffold a new game system with manifest, directory, CLAUDE.md, and stub test.

## Gather Requirements

Ask the user for:
1. **System name** -- e.g., "Tire Wear" (used in manifest and file naming)
2. **Description** -- one-line summary for the manifest
3. **Script directory** -- where scripts live, e.g., `scripts/tire_wear/` (create if needed)
4. **Status** -- active, deprecated, or experimental. Default: active
5. **Dependencies** -- names of other systems this depends on (check `resources/manifests/` for valid names)
6. **Entry point** -- main script path, e.g., `scripts/tire_wear/tire_wear.gd` (or `.cs`, `.py`, etc.)

If the user provides a system name only, derive sensible defaults:
- Script dir: `scripts/<snake_case_name>/`
- Entry point: `scripts/<snake_case_name>/<snake_case_name>.<ext>` (use project's primary language extension)
- Status: active
- Dependencies: empty

## Step 1: Create the Manifest

Create `resources/manifests/<snake_case_name>.json` with this structure:

```json
{
  "name": "<snake_case_name>",
  "description": "<description>",
  "status": "ACTIVE",
  "files": ["<entry_point_path>"],
  "dependencies": [],
  "replaced_by": ""
}
```

Use status values: `ACTIVE`, `DEPRECATED`, or `EXPERIMENTAL`.

Adapt the manifest format to the project's engine if a different format is used (e.g., `.tres` for Godot, `.asset` for Unity). Check existing manifests in `resources/manifests/` for the correct format and mirror it exactly.

Commit immediately after creating.

## Step 2: Create the Script Directory and Entry Point

1. Create the script directory if it does not exist
2. Create a minimal entry point script with:
   - A class declaration (if the language supports named classes)
   - A doc comment with the description
   - Minimal boilerplate appropriate for the engine/language

Example (language-agnostic pseudocode):
```
class <ClassName>:
    """<description>"""
    pass
```

Match the coding style and conventions of existing scripts in the project.

Commit immediately after creating.

## Step 3: Create CLAUDE.md for the Directory

Create `scripts/<snake_case_name>/CLAUDE.md` following this pattern:

```markdown
# scripts/<snake_case_name>/

<One-line description of what this directory contains.>

## Files

| File | Class | Role |
|------|-------|------|
| `<entry_point>` | `<ClassName>` | <role description> |

## Relevant Skills

- List relevant skills from `.agents/skills/` based on the system's domain
```

Commit immediately after creating.

## Step 4: Create Stub Test File

Create a test file following the project's test framework conventions. Place it in the project's test directory (e.g., `tests/test_<snake_case_name>.<ext>`).

The stub should:
- Import/extend the project's test base class
- Contain a single placeholder/pending test
- Include a TODO comment pointing to TDD (Red-Green-Commit) workflow

Commit immediately after creating.

## Step 5: Update Parent CLAUDE.md Files

1. Add the new manifest to `resources/manifests/CLAUDE.md` file listing
2. Add the new script directory to `scripts/CLAUDE.md` subdirectories listing
3. Add the new test file to `tests/CLAUDE.md` test files listing

Commit after updating all CLAUDE.md files (single atomic change).

## Step 6: Verify

1. Run `just validate-registry` to confirm the manifest is valid and all referenced files exist
2. List the new directories and files to confirm everything was created
3. Report what was created with full file paths

If `just validate-registry` is not available, manually verify:
- The manifest file exists and is valid JSON/resource
- All paths referenced in the manifest point to real files
- The test file exists in the test directory

## Rules

- Follow the project's commit-per-file rule (commit immediately after creating/editing)
- Use paths consistent with the engine's resource system (e.g., `res://` for Godot, `Assets/` for Unity)
- snake_case for file names, PascalCase for class names (unless project conventions differ)
- Match the manifest format of existing manifests exactly -- check `resources/manifests/` first
- If the system has an autoload/singleton, note it in the manifest but do NOT modify engine config files -- tell the user to register it manually
- Check existing systems for naming patterns and follow them
