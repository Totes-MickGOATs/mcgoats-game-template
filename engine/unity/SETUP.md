# Unity Engine Setup

## Prerequisites

- **Unity Hub** — Download from [unity.com](https://unity.com/download)
- **Unity Editor** — LTS version recommended (install via Unity Hub)
- **C# IDE** — JetBrains Rider (recommended) or VS Code with C# Dev Kit

## Steps

### 1. Open project in Unity

Open Unity Hub, click "Open", and select this project directory. Unity will generate the `Library/` directory (this takes a few minutes on first open).

### 2. Configure MCP (optional)

The UnityMCP and coplay-mcp servers enable Claude Code to interact with the running Unity editor.

- The `.mcp.json` file is copied to the project root by the setup script
- Install the UnityMCP package: `npm install @anthropic/unity-mcp`
- Enable the MCP addon in Unity Editor

### 3. Run tests

Use Unity's built-in Test Runner:

```
Window > General > Test Runner
```

Or via CLI:

```bash
Unity -batchmode -runTests -testPlatform EditMode -projectPath .
```

## Worktree Support

When working in git worktrees, the setup script creates a junction/symlink to the main repo's `Library/` directory to avoid a full reimport.

## Directory Structure

```
Assets/              # All game assets, scripts, scenes
ProjectSettings/     # Unity project configuration
Packages/            # Package manifest
tests/               # Test files (EditMode / PlayMode)
```
