# Versioning Convention

This project follows [Semantic Versioning 2.0.0](https://semver.org/).

## Format

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

| Component | When to bump |
|-----------|-------------|
| **MAJOR** | Breaking changes to gameplay, save format, or public API |
| **MINOR** | New features, content additions, non-breaking enhancements |
| **PATCH** | Bug fixes, performance improvements, polish |

## Pre-release Tags

| Tag | Meaning |
|-----|---------|
| `alpha` | Early development, unstable |
| `beta` | Feature-complete for milestone, testing phase |
| `rc` | Release candidate, final testing |

## Build Types

| Type | Description |
|------|------------|
| `dev` | Local development build |
| `ci` | Automated CI build |
| `release` | Production release |

## Release Lifecycle

1. Development on feature branches → merge to main
2. When ready for release: tag `vX.Y.Z-rc.1` → test
3. Final release: tag `vX.Y.Z` → build → publish

## Changelog

Generated automatically by [git-cliff](https://git-cliff.org/) from conventional commit messages. See `cliff.toml` for configuration.
