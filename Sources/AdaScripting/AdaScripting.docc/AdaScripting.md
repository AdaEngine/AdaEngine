# ``AdaScripting``

Write gameplay systems in Ada Script while keeping entity filtering and access planning in AdaEngine's native ECS.

@Metadata {
    @DisplayName("Ada Script")
}

## Overview

Ada Script is AdaEngine's gameplay scripting layer. Its source files use the `.ada` extension and run on the [Gravity](https://github.com/marcobambini/gravity) language runtime. AdaEngine adds declaration annotations, native ECS iterators, and component field capabilities.

Annotations are not only syntax. AdaEngine resolves every query into native archetypes and component columns and publishes its component access to the scheduler.

Use Ada Script for gameplay rules that benefit from quick iteration. Keep rendering backends, custom data structures, and other low-level or performance-critical facilities in Swift.

```ada
@system(scheduler: "update")
class MovementSystem {
    @query(Transform, Movement)
    var movers;

    func update(context) {
        for (var entity in movers) {
            var position = entity.transform.position;
            var velocity = entity.movement.velocity;
            position[0] += velocity[0] * context.deltaTime;
            position[1] += velocity[1] * context.deltaTime;
            entity.transform.position = position;
        }
    }
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
- ``GravityScriptValue``
- ``GravityScriptError``
