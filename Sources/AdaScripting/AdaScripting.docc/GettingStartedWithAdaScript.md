# Getting Started with Ada Script

Add an `.ada` file to an AdaEngine executable and run its systems without manually loading each script.

## Overview

AdaEngine provides two ways to install Ada Script plugins:

- **Automatic discovery** embeds every `.ada` file in an executable target at build time and generates one Swift plugin that installs them all.
- **Manual loading** creates a ``GravityScriptPlugin`` from source text or a file URL at runtime.

AdaEditor-created projects use automatic discovery. Use manual loading when scripts live outside the Swift target, come from a downloaded package, or need explicit error handling.

## Create a script

Add `Movement.ada` anywhere below the executable target's source directory, for example:

```text
Sources/MyGame/
├── main.swift
└── Scripts/
    └── Movement.ada
```

Declare a system and its query with annotations:

```ada
@system(scheduler: "update")
class MovementSystem {
    @query(Transform)
    var transforms;

    func update(context) {
        for (var entity in transforms) {
            var position = entity.transform.position;
            position[0] += 100 * context.deltaTime;
            entity.transform.position = position;
        }
    }
}
```

AdaEngine discovers `@system` and `@query` metadata and calls `update(context)` whenever the selected scheduler runs.

## Enable automatic discovery

Expose `AdaScriptBuildPlugin` to your executable target in `Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MyGame",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(
            url: "https://github.com/AdaEngine/AdaEngine.git",
            branch: "main"
        )
    ],
    targets: [
        .executableTarget(
            name: "MyGame",
            dependencies: [
                .product(name: "AdaEngine", package: "AdaEngine")
            ],
            plugins: [
                .plugin(name: "AdaScriptBuildPlugin", package: "AdaEngine")
            ]
        )
    ]
)
```

> Important: Choose a version requirement appropriate for your project instead of a branch dependency when consuming a released AdaEngine version.

The build plugin finds `.ada` files through SwiftPM, sorts them by target-relative path, and generates `AdaScriptPluginsGenerated.swift` in the plugin work directory. Script source is embedded in the executable; the original files are not read at runtime.

Install the generated plugin in your app scene:

```swift
import AdaEngine

@main
struct MyGame: App {
    var body: some AppScene {
        WindowGroup {
            GameView()
        }
        .addPlugins(AdaScriptPluginsGenerated())
    }
}
```

Rebuilding the target after adding, removing, renaming, or editing an `.ada` file refreshes the generated source. Files ending in `.gravity` are supported by manual loading but are not discovered by `AdaScriptBuildPlugin`.

## Register custom components

Ada Script resolves component names while plugins are set up. Register custom Swift components before the generated script plugin:

```swift
import AdaEngine

@Component
struct Movement: Codable, Sendable {
    var velocity: Vector2
}

struct GameComponentsPlugin: Plugin {
    @MainActor
    func setup(in app: borrowing AppWorlds) {
        Movement.registerComponent()
    }
}

@main
struct MyGame: App {
    var body: some AppScene {
        WindowGroup {
            GameView()
        }
        .addPlugins(
            GameComponentsPlugin(),
            AdaScriptPluginsGenerated()
        )
    }
}
```

The `@Component` macro supplies field reflection for supported property types. A plain `Component` can participate in query matching, but its fields are not automatically available through the script bridge.

## Load a script manually

Create a ``GravityScriptPlugin`` when you need control over the source location or loading failure:

```swift
import AdaEngine

struct RuntimeScriptsPlugin: Plugin {
    let scriptURL: URL

    @MainActor
    func setup(in app: borrowing AppWorlds) {
        do {
            let script = try GravityScriptPlugin(contentsOf: scriptURL)
            app.addPlugin(script)
        } catch {
            print("Could not load Ada Script: \(error)")
        }
    }
}
```

You can also use ``GravityScriptPlugin/init(source:name:)`` when the source is already in memory. Script compilation and annotation validation happen during initialization. Native component resolution happens later during plugin setup.

## Next steps

Read <doc:AdaScriptLanguage> for annotation syntax, then <doc:AdaScriptECS> for queries, component fields, and native iterator behavior.
