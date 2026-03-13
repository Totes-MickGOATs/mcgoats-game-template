# Contributing to mcgoats-game-template

Thank you for helping improve this template! This guide covers contributing back to the template itself.

## How to Contribute

### Reporting Issues
- Use GitHub Issues for bugs, feature requests, and questions
- Include your engine type and OS in bug reports

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-improvement`
3. Make your changes following the conventions below
4. Test your changes (see Testing section)
5. Submit a PR against `main`

### What Makes a Good Contribution

**Great contributions:**
- New engine-agnostic skills
- Improved CI workflows
- Better Claude Code hooks
- New CLAUDE.md templates
- Documentation improvements
- Bug fixes in setup-engine.sh

**Engine-specific contributions:**
- New engine modules (e.g., Bevy, Defold)
- Engine-specific skills (go in `engine/<engine>/skills/`)
- Engine-specific CI workflows
- Engine-specific hooks

### Conventions

- **Commit messages:** Conventional Commits (`feat:`, `fix:`, `docs:`, etc.)
- **Engine-agnostic by default:** Put engine-specific content in `engine/<engine>/`
- **Skills format:** Each skill is a directory with a `SKILL.md` file
- **Commands format:** Markdown files in `.claude/commands/<category>/`
- **Templates:** Use `<!-- ENGINE-SPECIFIC: ... -->` comments for engine placeholders

### Testing Your Changes

1. Create a new repo from the template
2. Run `bash tools/setup-engine.sh <engine>` for each engine you modified
3. Verify:
   - Git hooks work (`git config core.hooksPath .githooks`)
   - `just --list` shows all recipes
   - `just python-lint` passes
   - `just validate-registry` passes
   - CI workflows have valid YAML syntax

### Adding a New Engine Module

1. Create `engine/<engine>/` with:
   - `SETUP.md` — engine-specific setup instructions
   - `.mcp.json` — MCP server configuration
   - `justfile.engine` — engine-specific just recipes
   - `.gitignore.append` — engine-specific ignore patterns
   - `hooks/` — engine-specific hook scripts
   - `ci/` — engine-specific CI workflows
   - `skills/` — engine-specific skills (optional)
   - `commands/` — engine-specific commands (optional)
2. Update `tools/setup-engine.sh` to handle the new engine
3. Update `README.md` engine support table
4. Test the full setup flow

### Syncing Template Updates to Existing Projects

Projects created from this template can pull updates:

```bash
git remote add template https://github.com/Totes-MickGOATs/mcgoats-game-template.git
git fetch template
git merge template/main --no-ff --allow-unrelated-histories
```

Resolve any conflicts, then commit. Engine-specific files won't conflict if they were removed by setup-engine.sh.

## Code of Conduct

Be kind, be constructive, be helpful. We're all here to make game development with AI better.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
