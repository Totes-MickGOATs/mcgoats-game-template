# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Initial template release
- 9 GitHub Actions workflows (auto-merge, CI, post-merge tests, coverage, cleanup, stale, monitor, PR guard, template validation)
- 3-layer main branch protection (Claude Code hook, git hooks, GitHub branch protection)
- 12 Claude Code commands (2 ci/, 10 dev/)
- 52 skills (5 engine-agnostic, 47 Godot-specific)
- Engine modules: Godot (full), Unity (stubs), Unreal (stubs)
- Interactive setup script (`tools/setup-engine.sh`)
- Python validation tooling (CLAUDE.md freshness, registry, coverage)
- Knowledge base templates (plans, research, ADRs, system overview)
- CLAUDE.md directory templates for common project structures
- Subagent patterns and E2E testing architecture guides
- Dependabot configuration for GitHub Actions and Python deps
