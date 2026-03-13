# Unity Project Foundations

> Project structure, assembly definitions, version control setup, package management, and code style -- the foundation that every Unity project needs before writing game code.

## Recommended Folder Structure

```
Assets/
  Art/
    Materials/
    Models/
    Textures/
    Shaders/
    Animations/
    VFX/
  Audio/
    Music/
    SFX/
    Ambience/
  Prefabs/
    Characters/
    Environment/
    UI/
    VFX/
  Resources/              -- Only for assets loaded via Resources.Load (minimize usage)
  Scenes/
    Boot.unity
    MainMenu.unity
    Gameplay/
  Scripts/
    Runtime/
      Core/               -- Managers, singletons, bootstrapper
      Gameplay/            -- Game-specific logic
      UI/                  -- Menu, HUD, overlays
      Audio/               -- Audio managers, mixers
      Utils/               -- Extension methods, helpers
    Editor/                -- Editor scripts, custom inspectors, build tools
    Tests/
      EditMode/
      PlayMode/
  Settings/                -- ScriptableObject configs, data assets
  StreamingAssets/          -- Files that need to exist as-is on disk (JSON configs, etc.)
  Plugins/                 -- Third-party native plugins
  ThirdParty/              -- Third-party Unity packages not from UPM
```

**Key rules:**
- One script per file, filename matches class name exactly
- `Editor/` folders are stripped from builds -- use for tools, inspectors, build scripts
- Minimize `Resources/` usage -- everything in it is included in the build whether referenced or not
- `StreamingAssets/` contents are copied as-is to the build (not compressed)

## Assembly Definitions (.asmdef)

Assembly definitions control how your code compiles. Without them, every script goes into one giant `Assembly-CSharp.dll` -- any change recompiles everything.

### Why They Matter

1. **Compile time:** Change one file, only its assembly recompiles (seconds vs minutes)
2. **Dependency control:** Assemblies explicitly declare what they reference -- prevents spaghetti dependencies
3. **Testability:** Test assemblies reference game assemblies, not the other way around
4. **Platform targeting:** Mark assemblies as editor-only, test-only, or platform-specific

### Recommended Assembly Split

```
Assets/Scripts/Runtime/Game.Runtime.asmdef
  - Your game code
  - References: Unity assemblies only (no editor, no test)

Assets/Scripts/Editor/Game.Editor.asmdef
  - Custom inspectors, editor windows, build tools
  - References: Game.Runtime, UnityEditor
  - Platforms: Editor only

Assets/Scripts/Tests/EditMode/Game.Tests.EditMode.asmdef
  - Unit tests (no scene, no MonoBehaviour)
  - References: Game.Runtime, UnityEngine.TestRunner, NUnit
  - Test assembly: Yes, EditMode

Assets/Scripts/Tests/PlayMode/Game.Tests.PlayMode.asmdef
  - Integration tests (scene, GameObjects, coroutines)
  - References: Game.Runtime, UnityEngine.TestRunner, NUnit
  - Test assembly: Yes, PlayMode

Assets/ThirdParty/SomePlugin/SomePlugin.asmdef
  - Third-party code isolated in its own assembly
  - Game.Runtime references this if needed
```

### Creating an Assembly Definition

Right-click in Project -> Create -> Assembly Definition.

```json
// Game.Runtime.asmdef (example)
{
    "name": "Game.Runtime",
    "rootNamespace": "Game",
    "references": [],
    "includePlatforms": [],
    "excludePlatforms": [],
    "allowUnsafeCode": false,
    "overrideReferences": false,
    "precompiledReferences": [],
    "autoReferenced": true,
    "defineConstraints": [],
    "versionDefines": [],
    "noEngineReferences": false
}
```

```json
// Game.Editor.asmdef
{
    "name": "Game.Editor",
    "rootNamespace": "Game.Editor",
    "references": ["Game.Runtime"],
    "includePlatforms": ["Editor"],
    "excludePlatforms": [],
    "allowUnsafeCode": false,
    "overrideReferences": false,
    "precompiledReferences": [],
    "autoReferenced": true,
    "defineConstraints": [],
    "versionDefines": [],
    "noEngineReferences": false
}
```

```json
// Game.Tests.EditMode.asmdef
{
    "name": "Game.Tests.EditMode",
    "rootNamespace": "Game.Tests",
    "references": [
        "Game.Runtime",
        "UnityEngine.TestRunner",
        "UnityEditor.TestRunner"
    ],
    "includePlatforms": ["Editor"],
    "excludePlatforms": [],
    "allowUnsafeCode": false,
    "overrideReferences": true,
    "precompiledReferences": ["nunit.framework.dll"],
    "autoReferenced": false,
    "defineConstraints": ["UNITY_INCLUDE_TESTS"],
    "versionDefines": [],
    "noEngineReferences": false
}
```

### Dependency Rules

```
Game.Tests.EditMode  -->  Game.Runtime  (tests can reference game code)
Game.Tests.PlayMode  -->  Game.Runtime  (tests can reference game code)
Game.Editor          -->  Game.Runtime  (editor tools can reference game code)
Game.Runtime         -/-> Game.Editor   (NEVER -- game code must not reference editor code)
Game.Runtime         -/-> Game.Tests.*  (NEVER -- game code must not reference tests)
```

## Package Manager (UPM)

### Built-in Packages

Window -> Package Manager -> Unity Registry. Common essential packages:

| Package | Purpose |
|---------|---------|
| Input System | Modern input handling (replaces legacy Input) |
| TextMeshPro | Text rendering (replaces UI.Text) |
| Cinemachine | Camera system |
| ProBuilder | Level prototyping |
| Addressables | Asset management for large projects |
| Test Framework | Unit and integration testing |

### Git Packages

Add packages from git URLs via Window -> Package Manager -> + -> Add package from git URL.

```json
// Packages/manifest.json
{
    "dependencies": {
        "com.cysharp.unitask": "https://github.com/Cysharp/UniTask.git?path=src/UniTask/Assets/Plugins/UniTask#2.5.10",
        "com.neuecc.unirx": "https://github.com/neuecc/UniRx.git?path=Assets/Plugins/UniRx/Scripts"
    }
}
```

**Pin versions** with `#tag` or `#commit-hash` to prevent surprise breakage.

### Scoped Registries

For packages hosted on custom registries (e.g., OpenUPM).

```json
// Packages/manifest.json
{
    "scopedRegistries": [
        {
            "name": "OpenUPM",
            "url": "https://package.openupm.com",
            "scopes": [
                "com.cysharp",
                "com.neuecc"
            ]
        }
    ]
}
```

### Local Packages

For packages you develop alongside your project.

```json
// Packages/manifest.json
{
    "dependencies": {
        "com.mycompany.core": "file:../../SharedPackages/com.mycompany.core"
    }
}
```

## Version Control Setup

### .gitignore

```gitignore
# Unity generated
/[Ll]ibrary/
/[Tt]emp/
/[Oo]bj/
/[Bb]uild/
/[Bb]uilds/
/[Ll]ogs/
/[Uu]ser[Ss]ettings/

# Visual Studio / Rider
.vs/
.idea/
*.csproj
*.sln
*.suo
*.user
*.userprefs
*.pidb
*.booproj
*.svd
*.pdb
*.mdb
*.opendb
*.VC.db

# OS
.DS_Store
Thumbs.db

# Builds
*.apk
*.aab
*.unitypackage
*.app

# Crashlytics
crashlytics-build.properties

# Addressables
/[Aa]ssets/[Aa]ddressable[Aa]ssets[Dd]ata/*/*.bin*
/[Aa]ssets/[Ss]treamingAssets/aa.meta
/[Aa]ssets/[Ss]treamingAssets/aa/*
```

### .gitattributes

```gitattributes
# Unity YAML merge
*.unity merge=unityyamlmerge eol=lf
*.prefab merge=unityyamlmerge eol=lf
*.asset merge=unityyamlmerge eol=lf
*.meta merge=unityyamlmerge eol=lf

# Git LFS — binary assets that should not be diffed
*.png filter=lfs diff=lfs merge=lfs -text
*.jpg filter=lfs diff=lfs merge=lfs -text
*.jpeg filter=lfs diff=lfs merge=lfs -text
*.psd filter=lfs diff=lfs merge=lfs -text
*.tga filter=lfs diff=lfs merge=lfs -text
*.tif filter=lfs diff=lfs merge=lfs -text
*.exr filter=lfs diff=lfs merge=lfs -text
*.hdr filter=lfs diff=lfs merge=lfs -text
*.fbx filter=lfs diff=lfs merge=lfs -text
*.obj filter=lfs diff=lfs merge=lfs -text
*.blend filter=lfs diff=lfs merge=lfs -text
*.glb filter=lfs diff=lfs merge=lfs -text
*.gltf filter=lfs diff=lfs merge=lfs -text
*.wav filter=lfs diff=lfs merge=lfs -text
*.mp3 filter=lfs diff=lfs merge=lfs -text
*.ogg filter=lfs diff=lfs merge=lfs -text
*.aif filter=lfs diff=lfs merge=lfs -text
*.ttf filter=lfs diff=lfs merge=lfs -text
*.otf filter=lfs diff=lfs merge=lfs -text
*.mp4 filter=lfs diff=lfs merge=lfs -text
*.mov filter=lfs diff=lfs merge=lfs -text
*.dll filter=lfs diff=lfs merge=lfs -text
*.so filter=lfs diff=lfs merge=lfs -text
*.dylib filter=lfs diff=lfs merge=lfs -text
*.cubemap filter=lfs diff=lfs merge=lfs -text
*.unitypackage filter=lfs diff=lfs merge=lfs -text
```

### Force Text Serialization (MANDATORY)

Edit -> Project Settings -> Editor -> Asset Serialization -> Mode: **Force Text**

This converts all `.unity`, `.prefab`, `.asset`, `.meta` files to YAML text format. Without this:
- Binary scene files cannot be merged
- Diffs are meaningless
- Merge conflicts are unresolvable

**Check:** `ProjectSettings/EditorSettings.asset` should contain `m_SerializationMode: 2` (Force Text).

### What to Commit in ProjectSettings/

```
ProjectSettings/              -- COMMIT ALL OF THESE
  AudioManager.asset
  ClusterInputManager.asset
  DynamicsManager.asset       -- Physics settings
  EditorBuildSettings.asset   -- Scene list
  EditorSettings.asset        -- Serialization mode, etc.
  GraphicsSettings.asset
  InputManager.asset          -- Input axes (legacy) or Input System settings
  NavMeshAreas.asset
  PackageManagerSettings.asset
  Physics2DSettings.asset
  PlayerSettings.asset        -- Build target, company name, resolution, etc.
  PresetManager.asset
  ProjectSettings.asset
  QualitySettings.asset
  TagManager.asset            -- Tags and layers
  TimeManager.asset
  UnityConnectSettings.asset
  VFXManager.asset
  XRSettings.asset

Packages/
  manifest.json               -- COMMIT (package dependencies)
  packages-lock.json          -- COMMIT (exact resolved versions)
```

## Code Style

### .editorconfig

Place at repository root. Rider and Visual Studio respect this automatically.

```ini
# .editorconfig
root = true

[*.cs]
# Indentation
indent_style = space
indent_size = 4
tab_width = 4

# Line endings
end_of_line = lf
insert_final_newline = true
charset = utf-8

# Naming conventions
# Private fields: _camelCase
dotnet_naming_rule.private_fields.symbols = private_fields
dotnet_naming_rule.private_fields.style = underscore_camel_case
dotnet_naming_rule.private_fields.severity = warning

dotnet_naming_symbols.private_fields.applicable_kinds = field
dotnet_naming_symbols.private_fields.applicable_accessibilities = private, protected

dotnet_naming_style.underscore_camel_case.required_prefix = _
dotnet_naming_style.underscore_camel_case.capitalization = camel_case

# Public members: PascalCase
dotnet_naming_rule.public_members.symbols = public_members
dotnet_naming_rule.public_members.style = pascal_case
dotnet_naming_rule.public_members.severity = warning

dotnet_naming_symbols.public_members.applicable_kinds = property, method, event
dotnet_naming_symbols.public_members.applicable_accessibilities = public

dotnet_naming_style.pascal_case.capitalization = pascal_case

# Constants: PascalCase
dotnet_naming_rule.constants.symbols = constants
dotnet_naming_rule.constants.style = pascal_case
dotnet_naming_rule.constants.severity = warning

dotnet_naming_symbols.constants.applicable_kinds = field
dotnet_naming_symbols.constants.required_modifiers = const

# Code style
csharp_style_var_for_built_in_types = false:suggestion
csharp_style_var_when_type_is_apparent = true:suggestion
csharp_style_var_elsewhere = false:suggestion
csharp_prefer_braces = true:warning
csharp_style_expression_bodied_methods = when_on_single_line:suggestion
csharp_style_expression_bodied_properties = true:suggestion
```

### File Organization

```csharp
// One class per file. Filename = class name.
// PlayerController.cs contains class PlayerController

using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Events;

namespace Game.Gameplay
{
    /// <summary>
    /// Controls player movement, jumping, and ground detection.
    /// </summary>
    [RequireComponent(typeof(Rigidbody))]
    public class PlayerController : MonoBehaviour
    {
        // 1. Constants
        private const float GroundCheckDistance = 0.1f;

        // 2. Serialized fields (grouped with Headers)
        [Header("Movement")]
        [SerializeField] private float _moveSpeed = 5f;
        [SerializeField] private float _jumpForce = 8f;

        [Header("Ground Detection")]
        [SerializeField] private LayerMask _groundLayer;
        [SerializeField] private Transform _groundCheck;

        [Header("Events")]
        [SerializeField] private UnityEvent _onJumped;

        // 3. Public properties
        public bool IsGrounded { get; private set; }
        public float CurrentSpeed => _rb.linearVelocity.magnitude;

        // 4. Events
        public event Action<float> OnSpeedChanged;

        // 5. Private fields
        private Rigidbody _rb;
        private Vector2 _moveInput;

        // 6. Unity lifecycle (in execution order)
        private void Awake()
        {
            _rb = GetComponent<Rigidbody>();
        }

        private void OnEnable()
        {
            // Subscribe to events
        }

        private void OnDisable()
        {
            // Unsubscribe from events
        }

        private void Update()
        {
            ReadInput();
            CheckGround();
        }

        private void FixedUpdate()
        {
            Move();
        }

        // 7. Public methods
        public void Jump()
        {
            if (!IsGrounded) return;
            _rb.AddForce(Vector3.up * _jumpForce, ForceMode.Impulse);
            _onJumped?.Invoke();
        }

        // 8. Private methods
        private void ReadInput()
        {
            _moveInput = new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
        }

        private void CheckGround()
        {
            IsGrounded = Physics.CheckSphere(_groundCheck.position, GroundCheckDistance, _groundLayer);
        }

        private void Move()
        {
            Vector3 velocity = new Vector3(_moveInput.x * _moveSpeed, _rb.linearVelocity.y, _moveInput.y * _moveSpeed);
            _rb.linearVelocity = velocity;
        }
    }
}
```

### Namespace Convention

```csharp
namespace Game { }                    // Core/shared
namespace Game.Gameplay { }           // Gameplay systems
namespace Game.UI { }                 // UI scripts
namespace Game.Audio { }              // Audio systems
namespace Game.Utils { }              // Utilities
namespace Game.Editor { }             // Editor-only (in Editor asmdef)
namespace Game.Tests { }              // Tests (in Test asmdef)
```

## Editor Settings Checklist

Before first commit, verify these settings:

| Setting | Location | Required Value |
|---------|----------|----------------|
| Serialization Mode | Editor Settings | Force Text |
| Visible Meta Files | Editor Settings | Visible (version control mode) |
| Default Behavior Mode | Editor Settings | 3D or 2D (match your project) |
| Color Space | Player Settings | Linear (for PBR) or Gamma |
| Scripting Backend | Player Settings | IL2CPP (for builds) or Mono (for dev) |
| API Compatibility | Player Settings | .NET Standard 2.1 or .NET Framework |
| Enter Play Mode Settings | Project Settings | Enabled, with Domain/Scene Reload disabled for fast iteration |

### Enter Play Mode Settings

Edit -> Project Settings -> Editor -> Enter Play Mode Settings.

When enabled with "Reload Domain" unchecked, entering play mode is near-instant. But you must handle static state manually:

```csharp
public class ScoreManager : MonoBehaviour
{
    private static int _totalScore;

    // Reset static state when entering play mode without domain reload
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    private static void ResetStatics()
    {
        _totalScore = 0;
    }
}
```

**Rule:** Every class with `static` fields needs a `[RuntimeInitializeOnLoadMethod]` reset method when using fast enter play mode. Without it, static state bleeds between play sessions.

## Build Pipeline Basics

```csharp
// Editor script for automated builds
#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.Build.Reporting;

public static class BuildScript
{
    [MenuItem("Build/Windows")]
    public static void BuildWindows()
    {
        var options = new BuildPlayerOptions
        {
            scenes = GetBuildScenes(),
            locationPathName = "Builds/Windows/Game.exe",
            target = BuildTarget.StandaloneWindows64,
            options = BuildOptions.None,
        };

        BuildReport report = BuildPipeline.BuildPlayer(options);
        if (report.summary.result != BuildResult.Succeeded)
        {
            throw new System.Exception($"Build failed: {report.summary.totalErrors} errors");
        }
    }

    private static string[] GetBuildScenes()
    {
        var scenes = new System.Collections.Generic.List<string>();
        foreach (var scene in EditorBuildSettings.scenes)
        {
            if (scene.enabled) scenes.Add(scene.path);
        }
        return scenes.ToArray();
    }
}
#endif
```

## Common Mistakes

1. **No assembly definitions** -- every change recompiles everything, 30-second iteration time
2. **Binary serialization mode** -- impossible to diff or merge scenes
3. **No .gitignore** -- Library/ (10+ GB) gets committed, repo becomes unusable
4. **No Git LFS** -- textures and models bloat the repo permanently (git history keeps every version)
5. **Scripts in Assets root** -- no namespace boundaries, everything depends on everything
6. **Using Resources folder liberally** -- everything in Resources is included in the build
7. **No .editorconfig** -- inconsistent code style, noisy diffs from formatting changes
8. **Skipping Enter Play Mode Settings** -- waiting 5-10 seconds to test every change
