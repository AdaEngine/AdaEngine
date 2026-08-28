# ``AdaScripting``

Write gameplay systems in Ada Script while keeping entity filtering and access planning in AdaEngine's native ECS.

@Metadata {
    @DisplayName("Ada Script")
}

## Overview

Ada Script is AdaEngine's gameplay scripting layer. Its source files use the `.ada` extension and run on the [Gravity](https://github.com/marcobambini/gravity) language runtime. AdaEngine adds a small ECS API on top of the language: a script declares a plugin, its systems, the scheduler for each system, and the components each system reads or writes.

The declaration is not only metadata. AdaEngine turns every script query into a native `EntityQuery` and publishes its component access to the scheduler. The script receives only the entities and fields allowed by that declaration.

Use Ada Script for gameplay rules that benefit from quick iteration. Keep rendering backends, custom data structures, and other low-level or performance-critical facilities in Swift.

```ada
class MovementSystem {
    func update(deltaTime, queries) {
        var movers = queries[0];

        for (var index in 0..<movers.count) {
            var position = movers.get(index, "Transform", "position");
            var velocity = movers.get(index, "Movement", "velocity");

            position[0] += velocity[0] * deltaTime;
            position[1] += velocity[1] * deltaTime;
            movers.set(index, "Transform", "position", position);
        }
    }
}

func main() {
    return AdaPlugin.create("Movement", [
        AdaSystem.createBatch("movement", "update", [
            AdaQuery.readWrite(
                ["Transform", "Movement"],
                ["Transform"]
            )
        ], MovementSystem())
    ]);
}
```

AdaEditor projects configure automatic script discovery by default. For an existing Swift package, follow <doc:GettingStartedWithAdaScript> to enable the build plugin and register the generated script plugins.

## Topics

### Essentials

- <doc:GettingStartedWithAdaScript>
- <doc:AdaScriptLanguage>

### ECS Integration

- <doc:AdaScriptECS>
- <doc:AdaScriptDiagnosticsAndPerformance>

### Runtime API

- ``GravityScriptPlugin``
- ``GravityScriptPluginDescriptor``
- ``GravityScriptSystemDescriptor``
- ``GravityScriptQueryDescriptor``
- ``GravityScriptExecutionMode``
- ``GravityScriptValue``
- ``GravityScriptError``
