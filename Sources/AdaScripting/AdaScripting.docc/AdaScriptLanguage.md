# Ada Script Language

Use Ada Script syntax with AdaEngine declaration annotations.

## Source files

Ada Script uses `.ada` files. A file contains classes,
functions, variables, and control flow. Ada Script modules do not declare a
`main()` function and do not assemble plugin manifests.

```ada
@system(scheduler: "update")
class CounterSystem {
    @query(Counter)
    var counters;

    func update(context) {
        for (var entity in counters) {
            entity.counter.value += 1;
        }
    }
}
```

## Imports

Files with discovery annotations such as `@system` are module roots. Import a
helper declaration explicitly from another target-relative source file:

```ada
import {
    clampSpeed,
    MovementSettings
} from "../Shared/Movement";
```

Relative imports are resolved from the importing file. The `.ada` extension is
optional. Absolute paths and imports which escape the Swift target source map
are rejected. A reachable source is compiled once, and an import cycle reports
the complete cycle.

The current implementation supports selected relative imports. Namespace
imports, public/private visibility enforcement, and the `AdaEngine` / `AdaUI`
virtual-module declarations remain part of the next module-language slice.

## Annotations

Ada Script declaration annotations have three forms:

```ada
@name
@name(value)
@name(key: value, other: [a, b])
```

Arguments are compile-time constants or symbolic identifiers. They do not run
user code during module discovery.

The initial AdaEngine annotations are:

- `@system` for ECS systems;
- `@query` for native ECS iterators;
- `@access` for explicit scheduler access;
- `@component` and `@resource` for generated data declarations;
- `@scriptable` for attached script objects;
- `@view` for declarative AdaUI views;
- `@previewable` for AdaUI views exposed in AdaEditor Preview;
- `@state` for state owned by an Ada Script view;
- `@environment` for read-only AdaUI environment values;
- `@export` for persistent and inspectable fields.

## Script-defined data

The build plugin generates native backing types for scalar component and
resource schemas:

```ada
@component(id: "game.health")
struct Health {
    @export var current = 100.0;
    @export var maximum = 120;
}

@resource(id: "game.balance", autoInsert: true)
struct GameBalance {
    @export var acceleration = 9.8;
}
```

The first schema slice supports `Bool`, signed `Int64`, finite `Double`, and
`String` defaults. Generated Swift symbol names are private implementation
details. Runtime lookup accepts both the Ada Script declaration name (`Health`) and
the stable ID (`game.health`). `autoInsert: true` inserts the generated resource
before systems are installed.

Bind a resource directly on a system with `@res`. The binding uses a native ECS
resource pointer during `update(context)`; field writes update the resource
change tick:

```ada
@system(id: "physics.system")
class PhysicsSystem {
    @res
    var balance: GameBalance;

    func update(context) {
        balance.acceleration += 0.1;
    }
}
```

A missing required resource is reported through plugin diagnostics. Optional
resources can be guarded with `available()`:

```ada
@res(optional: true)
var debugSettings: DebugSettings;

if (debugSettings.available()) {
    debugSettings.enabled = true;
}
```

Resource access is currently conservative: each `@res` requests scheduler write
access. Static read/write inference and explicit access overrides are planned.

## World commands

Systems receive a capability-scoped world facade. Structural changes are
queued through `context.world.commands` and applied only after the current
system parameters finish, so an active query iterator cannot be invalidated:

```ada
@system(id: "cleanup.system")
class CleanupSystem {
    @query(Expired)
    var expired;

    func update(context) {
        for (var entity in expired) {
            context.world.commands.despawn(entity.id);
        }
    }
}
```

The initial command API creates registered component defaults by Ada Script name
or stable ID:

```ada
var entity = context.world.commands.spawn(["game.health"]);
context.world.commands.insert(entity, "game.poison");
context.world.commands.remove(entity, "game.poison");
context.world.commands.despawn(entity);
```

Direct command use is inferred per system and declares deferred-world access to
the scheduler. Command facades expire when `update(context)` returns; using a
retained or undeclared facade reports a plugin diagnostic and performs no
mutation. Component constructor arguments, explicit dynamic `@access`, events,
assets, UI commands, and exclusive immediate world access are planned.

Script-defined data requires `AdaScriptBuildPlugin`; manual runtime-only source
loading cannot introduce a new native Swift layout.

Swift and Editor tooling can attach the generated default without naming its
private backing type:

```swift
world.insertDefaultComponent(named: "game.health", into: entity.id)
```

Generated-component dynamic mutation/removal and scene coding, vectors, colors,
enums, entity references, and asset references are not part of that data-schema
slice yet.

## Scriptable objects

Use `@scriptable` for low-cardinality behavior attached to one entity. Systems
remain the scalable path for processing large entity sets.

```ada
@scriptable(
    id: "game.player-controller",
    version: 2,
    aliases: ["PlayerController"]
)
class PlayerController {
    @export var speed = 8.0;
    @component(required: true) var transform: Transform;
    @res(optional: true) var settings: PlayerSettings;

    func ready(context) {}

    func update(context) {
        transform.position += speed * context.deltaTime;
    }

    func fixedUpdate(context) {}
    func event(events, context) {}
    func destroy(context) {}
}
```

The build plugin registers stable IDs, versions, aliases, exported scalar
defaults, and transient component/resource bindings. Required components are
checked before `ready`. Optional resources expose `available()`.

`ScriptableComponents` encodes a polymorphic envelope containing only `type`,
`version`, and detached `payload`. Entity bindings, resources, VM instances,
world contexts, and lifecycle state are never serialized. Decoding does not run
gameplay; attachment runs `ready` once and detachment runs `destroy` once.

Scriptable contexts expose the same expiring deferred commands facade as
systems. Retaining it after a callback produces a diagnostic. Scriptable
objects intentionally have no immediate-mode GUI callback; declarative UI
belongs to AdaUI script views.

## AdaUI views

Use `@view` on a class whose `body()` contains declarative AdaUI expressions.
Add `@previewable` when that view should appear in AdaEditor Preview. See
<doc:AdaScriptViews> for the supported view constructors, modifiers, and
preview workflow.

## System context

`update(context)` receives a scoped system context. `context.deltaTime` is the
current scheduler delta. Context and query values must not be retained after
the callback.

## State

Fields on a system instance persist between scheduler updates:

```ada
@system(scheduler: "update")
class LifetimeSystem {
    var elapsed = 0.0;

    func update(context) {
        elapsed += context.deltaTime;
    }
}
```

Use local variables for per-call calculations. Store ECS gameplay state in
components and shared singleton state in resources rather than global mutable
variables.

## Values crossing the bridge

Ada Script bridge values are detached booleans, integers, finite floating-point
numbers, strings, lists, and null. ECS component views are borrowed native
capabilities rather than detached values.

Unsupported values and invalid numeric conversions are rejected without
partially mutating a component.

System `update(context)` callbacks are command-style. Their return values are
ignored; observable behavior belongs in components, resources, events, or
diagnostics.
