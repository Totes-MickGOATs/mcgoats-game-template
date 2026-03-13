# Tests

Test files live here. Engine-specific test frameworks are configured during engine setup.

## Conventions

- **Naming:** `test_<system>.gd` (Godot), `Test<System>.cs` (Unity), `<System>Test.cpp` (Unreal)
- **TDD:** Write tests FIRST (Red), implement (Green), commit
- **Tiers:** Unit tests (always), integration tests (when wiring/signals involved), E2E (complex flows)

## Helpers

Shared test utilities live in `tests/helpers/`. Add reusable assertions, fixtures, and mock factories here.

## Running Tests

```bash
just test-fast <test_file>   # Single file (engine-specific)
just test                    # Full suite (CI only — don't run locally)
```
