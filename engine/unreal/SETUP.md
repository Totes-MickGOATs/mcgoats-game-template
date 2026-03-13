# Unreal Engine Setup

## Prerequisites

- **Epic Games Launcher** — Download from [unrealengine.com](https://www.unrealengine.com/download)
- **Unreal Engine** — Install via Epic Games Launcher
- **C++ toolchain** — Visual Studio 2022 (Windows) or Xcode (macOS) with C++ workload

## Steps

### 1. Generate project files

Open the `.uproject` file or use the Unreal Build Tool:

```bash
# Windows (from engine install directory)
UnrealBuildTool.exe -projectfiles -project="path/to/Project.uproject" -game -engine
```

### 2. Open in Unreal Editor

Double-click the `.uproject` file or launch from Epic Games Launcher.

### 3. Configure MCP (placeholder)

MCP integration for Unreal is not yet available. The `.mcp.json` is a placeholder.

### 4. Build and test

Use the Unreal Editor's built-in automation framework or compile from CLI.

## Worktree Support

When working in git worktrees, the setup script creates a junction/symlink to the main repo's `DerivedDataCache/` directory to avoid rebuilding shaders.

## Directory Structure

```
Source/              # C++ source files
Config/              # Engine and project configuration (.ini files)
Content/             # Assets (meshes, textures, blueprints)
Plugins/             # Engine/project plugins
```
