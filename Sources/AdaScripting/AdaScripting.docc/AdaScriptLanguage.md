# Ada Script Language

Use Gravity syntax with AdaEngine declaration annotations.

## Source files

Ada Script uses `.ada` files. A file contains ordinary Gravity classes,
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

Gravity declaration annotations have three forms:

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
- `@export` for persistent and inspectable fields.

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
