# Ada Script Diagnostics and Performance

Handle failures at the correct lifecycle stage and choose the scripting bridge appropriate for each workload.

## Diagnose loading failures

``GravityScriptPlugin`` performs three operations during initialization:

1. Compiles the Ada Script source together with AdaEngine's scripting prelude.
2. Executes `main()` once.
3. Validates the returned plugin, system, and query manifest.

Initialization throws ``GravityScriptError/compilation(_:)`` for compiler or VM errors and ``GravityScriptError/invalidManifest(_:)`` for a value with the wrong shape. Common manifest failures include:

- `main()` does not return `AdaPlugin.create(...)`.
- A system does not contain an identifier, scheduler, queries, and instance.
- A query contains values other than component-name strings.
- Two systems in one plugin use the same identifier.

Catch and report these errors at the loading boundary:

```swift
do {
    let plugin = try GravityScriptPlugin(source: source)
    app.addPlugin(plugin)
} catch let error as GravityScriptError {
    print(error.description)
}
```

When using automatic discovery, generated code catches each file's loading error, prints its target-relative path, and continues loading the remaining files.

## Inspect setup and runtime diagnostics

Component types are resolved during plugin setup because an earlier Swift plugin may register them. An unknown or ambiguous component does not make initialization throw. Instead, AdaEngine skips that system and adds an ``GravityScriptError/unknownComponent(system:queryIndex:component:)`` description to ``GravityScriptPlugin/diagnostics``.

Runtime bridge failures can also append diagnostics, including:

- An undeclared component or unknown field.
- A component without reflected fields.
- A read-only field.
- An unsupported, non-finite, out-of-range, or incorrectly shaped value.
- An invalid batch index.

Inspect diagnostics after setup and while developing a system:

```swift
for message in plugin.diagnostics {
    print("Ada Script: \(message)")
}
```

Diagnostics accumulate for the lifetime of the plugin. A failed `set` also returns `false`, which lets the script handle an expected capability failure without depending on log text.

## Test script systems

Run script behavior against a real `World`. Register components, spawn representative entities, install the plugin, run the scheduler, and inspect both ECS state and diagnostics:

```swift
import AdaApp
import AdaECS
import AdaScripting
import Testing

@Test
@MainActor
func movementScriptUpdatesPosition() async throws {
    Transform.registerComponent()

    let plugin = try GravityScriptPlugin(source: movementSource)
    let world = World(name: "Ada Script Test")
    let entity = world.spawn {
        Transform()
    }

    plugin.setup(in: AppWorlds(main: world))
    await world.runScheduler(.update)

    #expect(plugin.diagnostics.isEmpty)
    #expect(world.get(Transform.self, from: entity.id) != nil)
}
```

Use ``GravityScriptPlugin/lastResult(for:)`` for a compact assertion when the system deliberately returns a count or status. ECS state remains the primary evidence that gameplay behavior is correct.

## Choose batch mode for hot paths

Entity mode allocates one bridge proxy for every matched entity on every update. Batch mode allocates one bridge proxy per query and performs indexed access, so `AdaSystem.createBatch` is the preferred execution mode for large or frequently updated sets.

For either mode:

- Keep query declarations narrow so the scheduler sees the real access set.
- Cache values in script variables instead of repeating `get` calls.
- Perform one validated `set` after calculating the final field value.
- Split systems by scheduling and access needs, not merely by source-file organization.
- Move a workload to a native Swift system when bridge calls dominate its frame time.

AdaEngine serializes Gravity VM work because the embedded runtime is globally shared and non-reentrant. Multiple script files do not create parallel VM execution. Native ECS filtering and batch query preparation remain the scalable part of the scripting path.

## Current boundaries

The current Ada Script host has these deliberate constraints:

- Scripts cannot directly access `World`.
- Scripts cannot spawn or despawn entities or add and remove components.
- Resources, events, assets, rendering commands, and platform APIs are not bridged.
- Script files cannot import declarations from other script files.
- Automatic discovery embeds `.ada` source at build time; it is not runtime hot reload.
- Only reflected field values supported by the bridge can be mutated.

These boundaries keep scripts capability-scoped and preserve ECS scheduler knowledge. Add a narrow native Swift plugin or system when gameplay needs a facility that is not exposed.
