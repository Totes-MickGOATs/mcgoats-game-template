# engine/unity/

Unity engine module — comprehensive C# game development infrastructure. Copied to project root by `tools/setup-engine.sh`.

## Files

| File | Role |
|------|------|
| `SETUP.md` | Unity-specific setup instructions |
| `.mcp.json` | MCP server config (UnityMCP + coplay-mcp) |
| `justfile.engine` | Unity CLI recipes (test, build, lint, format) |
| `.gitignore.append` | Unity ignore patterns |

## Subdirectories

| Dir | Contents |
|-----|----------|
| `ci/` | CI workflow for C# linting + .meta file validation |
| `hooks/` | Pre-commit (.meta checks), lint-on-save (C# format), worktree-setup (Library junction) |
| `claude-md/` | CLAUDE.md templates for Assets/Scripts/, Assets/Scenes/, tests/ |
| `commands/` | Unity-specific slash commands (run-tests, compile-check) |
| `skills/` | 25 Unity game development skills (see below) |

## Skills (25)

### Core C# & Architecture
| Skill | Topics |
|-------|--------|
| `unity-csharp-mastery` | C# patterns, naming, async/await, LINQ, MonoBehaviour lifecycle, attributes |
| `unity-scriptable-objects` | Data architecture, event channels, runtime sets, variable pattern |
| `unity-scene-management` | Scene loading, additive scenes, bootstrapper pattern, DontDestroyOnLoad |
| `unity-state-machines` | Animator controllers, StateMachineBehaviour, custom FSM, hierarchical states |
| `unity-project-foundations` | Folder structure, assembly definitions, package manager, .editorconfig |
| `unity-composition` | Component architecture, interfaces, DI patterns, prefab composition |

### Physics & 3D
| Skill | Topics |
|-------|--------|
| `unity-physics-3d` | Rigidbody, colliders, joints, raycasting, layers, WheelCollider |
| `unity-3d-lighting` | URP/HDRP, baked/realtime, probes, lightmapping, post-processing |
| `unity-3d-materials` | Shader Graph, PBR, material property blocks, texture setup |
| `unity-3d-world-building` | Terrain, ProBuilder, prefabs, LOD, occlusion, NavMesh |
| `unity-shaders` | Shader Graph patterns, custom HLSL, render features, compute shaders |

### Gameplay
| Skill | Topics |
|-------|--------|
| `unity-input-system` | New Input System, action maps, rebinding, multiplayer input |
| `unity-camera-systems` | Cinemachine, virtual cameras, freelook, state-driven, Timeline |
| `unity-animation` | Animator, blend trees, IK, root motion, Animation Rigging, DOTween |
| `unity-audio-systems` | AudioMixer, spatial audio, pooling, music cross-fade, snapshots |
| `unity-particles-vfx` | Particle System, VFX Graph, common effect recipes, optimization |
| `unity-networking` | Netcode for GameObjects, NetworkVariable, RPCs, Relay+Lobby, LAN |

### UI & UX
| Skill | Topics |
|-------|--------|
| `unity-ui-toolkit` | UXML, USS, runtime UI, data binding, custom controls, responsive layout |
| `unity-ui-design` | Menu flows, canvas strategies, gamepad navigation, localization |

### Quality & Tools
| Skill | Topics |
|-------|--------|
| `unity-testing-patterns` | Unity Test Framework, EditMode/PlayMode, TDD, mocking, CI |
| `unity-debugging-profiling` | Profiler, Frame Debugger, Memory Profiler, Gizmos, custom tools |
| `unity-performance-optimization` | Batching, LOD, GC, pooling, occlusion, shader optimization |
| `unity-editor-scripting` | Custom inspectors, editor windows, property drawers, build pipeline |
| `unity-mcp-workflows` | UnityMCP + coplay-mcp tool usage, paging, workflows |

### Data & Platform
| Skill | Topics |
|-------|--------|
| `unity-save-load` | JSON/binary serialization, Addressables, PlayerPrefs, cloud saves |
