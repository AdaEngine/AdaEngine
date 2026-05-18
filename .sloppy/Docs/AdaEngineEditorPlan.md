# AdaEngine Editor — Architecture Baseline

This document records the agreed baseline for AdaEngine Editor so future work does not drift from the plan.

## 1. Repository boundary

AdaEngine Editor should be developed as a separate product/repository from the AdaEngine runtime.

- `AdaEngine` remains the runtime/framework/SDK.
- `AdaEngineEditor` is the editor/tooling/AI IDE product.
- The editor can depend on AdaEngine via Swift Package Manager.
- Local development may use path dependencies, but the runtime repository should not be forced to carry editor-only dependencies.

## 2. Project metadata layout

Every AdaEngine project should use a `.ada/` directory.

Canonical project file:

```text
.ada/project.json
```

Recommended project layout:

```text
MyGame/
  Package.swift
  Sources/
  Assets/
  Resources/
  .ada/
    project.json
    workspace.json
    cache/
    logs/
    indexes/
    ai/
      cache/
```

### Git policy

Should be committed:

```text
.ada/project.json
```

Should normally not be committed:

```text
.ada/workspace.json
.ada/cache/
.ada/logs/
.ada/indexes/
.ada/ai/cache/
```

## 3. `.ada/project.json`

`project.json` is the portable, project-level configuration used by the editor, agents, and AdaMCP.

It should include at least:

- `schemaVersion`
- project id/name/version
- engine information
- source/assets/resources paths
- build system configuration
- run configurations
- editor defaults
- AI/MCP context policy

Example MVP shape:

```json
{
  "schemaVersion": 1,
  "project": {
    "id": "com.example.mygame",
    "name": "My Game",
    "version": "0.1.0"
  },
  "paths": {
    "sources": "Sources",
    "assets": "Assets",
    "resources": "Resources"
  },
  "build": {
    "system": "swiftpm",
    "packageFile": "Package.swift"
  },
  "run": {
    "defaultConfiguration": "Game",
    "configurations": [
      {
        "name": "Game",
        "target": "MyGame",
        "arguments": [],
        "environment": {}
      }
    ]
  }
}
```

## 4. `.ada/workspace.json`

`workspace.json` is local user/editor state and should not be treated as portable project configuration.

It may contain:

- opened tabs
- selected run configuration
- active scene
- selected entity
- layout state
- local session state
- local absolute paths if needed

## 5. Editor principles

AdaEngine Editor is an AI-first editor around AdaEngine.

Core requirements:

- UI is AdaUI-first.
- NativeView is allowed only for narrow platform-specific cases.
- macOS-first implementation, then Windows, then iPadOS.
- No Xcode dependency for core workflows.
- Use Swift Package Manager and Swift CLI for build/run/test/dependency operations.
- iPadOS should likely use a remote build/agent host because local process spawning and debugging are limited.

## 6. Core editor modules

Planned modules:

- `EditorCore`
- `EditorProjectSystem`
- `EditorWorkspace`
- `EditorBuildSystem`
- `EditorDebugging`
- `EditorSourceControl`
- `EditorScene`
- `EditorECS`
- `EditorAssets`
- `EditorLogging`
- `EditorAI`
- `EditorMCP`
- `EditorHotReload`
- `EditorPlatform`

## 7. Build/run/debug

The editor should support SwiftPM workflows without requiring Xcode:

```bash
swift package resolve
swift build
swift run
swift test
swift package update
```

Run configurations should describe:

- target
- debug/release configuration
- arguments
- environment
- working directory
- debugger enabled/disabled

The editor must stream stdout/stderr, parse diagnostics, and expose build/run state to UI and agents.

## 8. ECS and scene integration

The editor must provide structured ECS/world access.

Agent/editor readable state:

- worlds
- entities
- components
- systems/resources where available
- selected entity
- scene hierarchy
- runtime logs

Mutation capabilities must include:

- create/delete entity
- add/remove/update component
- select/focus entity
- create common scene objects such as camera/light/sprite/mesh/empty

## 9. Command and permission model

Agents must not directly mutate project files or ECS/world state.

All mutations should go through an editor command system:

```swift
protocol EditorCommand {
    var title: String { get }
    func execute() async throws
    func undo() async throws
}
```

This provides:

- undo/redo
- audit trail
- approval flow
- safer agent operation
- consistent UI integration

Permission classes:

- read-only/safe
- project mutation
- execution/build/run/test
- dangerous/destructive

Policy options:

- ask always
- allow for this session
- allow for this project
- deny

## 10. AI and Sloppy integration

Sloppy is the primary AI/agent backend.

The editor should still use an abstraction so future backends can be added:

- Sloppy
- opencode
- codex
- Claude Code

Conceptual protocol:

```swift
protocol AgentBackend {
    var id: String { get }
    var displayName: String { get }
    func startSession(context: AgentContext) async throws -> AgentSession
    func send(_ message: AgentMessage, to session: AgentSession.ID) async throws
    func cancel(session: AgentSession.ID) async throws
}
```

## 11. AdaMCP / MCP requirements

AdaEngine Editor should expose an MCP server so Sloppy and other agents can inspect and operate the editor safely.

Required resources include:

```text
ada://project/config
ada://project/files
ada://workspace/state
ada://logs/recent
ada://diagnostics/problems
ada://scene/current
ada://ecs/world
```

Required tools include:

```text
get_project_info
list_files
read_file
get_logs
get_problems
build_project
run_project
list_entities
get_entity
propose_command
```

Direct destructive mutation tools should be avoided. Mutations should be proposed as commands and pass through permission checks.

## 12. MVP roadmap

### MVP 1 — Project shell

- recent projects
- open/import/create project
- read `.ada/project.json`
- file explorer
- build via `swift build`
- run via `swift run`
- logs panel
- basic settings
- AdaUI layout

### MVP 2 — Scene/ECS inspector

- runtime connection
- world overview
- entity list
- component inspector
- entity picker
- basic scene mutation through commands

### MVP 3 — AI panel with Sloppy

- agent chat
- project context
- logs/build context
- scene/ECS context
- file/entity/component change proposals
- approval UI

### MVP 4 — AdaMCP server

- resources/tools for project/workspace/logs/problems/scene/ECS
- permission-aware command proposals
- Sloppy integration verification

### MVP 5 — Source control and diagnostics

- git status/diff
- diagnostics/problems panel
- AI explain/fix diagnostics

## 13. Mandatory quality gate for every task

Every implementation task must include and record evidence for:

1. Unit tests.
2. Integration tests where relevant.
3. Negative/error tests where relevant.
4. Fixtures/snapshots where useful.
5. Manual smoke run for UI changes.
6. AdaMCP verification for agent-visible behavior.
7. Smallest relevant test run after the change.
8. Full project build before closing the task.
9. Evidence attached to the task: commands, results, build summary, AdaMCP verification summary.

The expected workflow is:

```text
feature -> tests -> run -> AdaMCP verification -> build -> evidence -> close
```

## 14. Open design questions

To resolve before deeper implementation:

1. Runtime/editor bridge transport: IPC, WebSocket, local TCP, embedded bridge, or MCP-facing bridge.
2. ECS component serialization/reflection model.
3. Source of truth for scene state: scene file, running ECS world, or editor document model.
4. Whether the editor needs a plugin system early.
5. Exact Sloppy embedding mode: local runtime, daemon, MCP client/server, or CLI/API adapter.

