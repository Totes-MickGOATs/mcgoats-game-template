# claude-md-templates/

Template CLAUDE.md files for common game project directories.

Copy and customize these when creating new directories in your project.

## Available Templates

| Template | For Directory | Contains |
|----------|--------------|----------|
| `autoloads-CLAUDE.md` | Autoload/singleton scripts | Autoload table, signal conventions |
| `ui-CLAUDE.md` | UI scripts and scenes | Focus, filter, process mode conventions |
| `tests-CLAUDE.md` | Test files | TDD conventions, helper table |
| `effects-CLAUDE.md` | Visual/audio effects | Effect categories, particle conventions |
| `core-CLAUDE.md` | Core framework classes | Registry system description |
| `scripts-tools-CLAUDE.md` | Python build tools | Script table, uv usage |
| `resources-CLAUDE.md` | Game resources | Resource directory table |

## Usage

```bash
# Example: creating a new ui/ directory
mkdir -p scripts/ui
cp claude-md-templates/ui-CLAUDE.md scripts/ui/CLAUDE.md
# Then customize with your project's specific UI scripts
```
