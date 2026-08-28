# Ada Script Language

Learn the Gravity-based syntax used by `.ada` files and the entry point AdaEngine expects.

## Language model

Ada Script uses Gravity, a dynamically typed, class-based language. Variables do not declare a required type by default, and the runtime types commonly used by gameplay code are:

| Type | Example | Typical use |
| --- | --- | --- |
| `Bool` | `true` | Conditions and component flags |
| `Int` | `42` | Counters, indices, and integer fields |
| `Float` | `0.016` | Time, positions, and scalar fields |
| `String` | `"player"` | Names and string fields |
| `List` | `[1, 2, 3]` | Collections and vectors crossing the ECS bridge |
| `Map` | `["score": 100]` | Script-local keyed data |
| `Range` | `0..<count` | Indexed loops |
| `Null` | `null` | Missing or unavailable values |

Statements conventionally end with a semicolon. `//` starts a line comment.

```ada
var speed = 120;
var enabled = true;
var tags = ["player", "moving"];

if (enabled and speed > 0) {
    speed += 10;
}
```

## Functions and classes

Declare functions with `func`. A script system is an ordinary class instance with an `update` method:

```ada
func clamp(value, minimum, maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
}

class HealthSystem {
    func update(deltaTime, queries) {
        return queries[0].count;
    }
}
```

The instance is created while `main()` builds the manifest, so its fields persist across updates:

```ada
class TimerSystem {
    var elapsed = 0;

    func update(deltaTime, queries) {
        elapsed += deltaTime;
        return elapsed;
    }
}
```

## Lists and loops

Lists use zero-based indexing. Use a half-open range to visit indices from zero through `count - 1`:

```ada
var values = [10, 20, 30];

for (var index in 0..<values.count) {
    values[index] *= 2;
}
```

An entity-mode query is a list, so access an entity with `queries[queryIndex][entityIndex]`. A batch-mode query is an `AdaQueryBatch`; use its `count`, `get`, and `set` members instead of subscripting it. See <doc:AdaScriptECS> for both modes.

## The `main()` contract

Every automatically discovered `.ada` file is compiled as a separate script plugin and must define a global `main()` function. The function executes once when ``GravityScriptPlugin`` is initialized and must return `AdaPlugin.create(name, systems)`:

```ada
func main() {
    return AdaPlugin.create("Gameplay", [
        AdaSystem.create(
            "health.regeneration",
            "update",
            [AdaQuery.write(["Health"])],
            HealthRegenerationSystem()
        )
    ]);
}
```

Plugin names and system identifiers are runtime identities, not display-only labels. System identifiers must be unique inside one script. Keep each `(plugin name, system identifier)` pair unique across the application as well.

## Host values and return values

AdaEngine calls a system's update method with two arguments:

- `deltaTime` is the frame delta in seconds. It is `0` if no `DeltaTime` resource is available.
- `queries` contains one result for each query in the manifest, in declaration order.

The update method may return a value. AdaEngine detaches `null`, booleans, integers, floats, strings, and nested lists from the VM, and exposes the most recent result through ``GravityScriptPlugin/lastResult(for:)``. Return values are useful for tests and diagnostics; they do not drive ECS scheduling.

```swift
if case .integer(let count) = plugin.lastResult(for: "health.regeneration") {
    print("Updated \(count) entities")
}
```

## Script boundaries

Each `.ada` file owns a separate plugin manifest and runtime instance. Declarations from one file are not automatically visible to another file. The current host does not provide file loading or imports, so keep shared behavior within one script or move it into a native Swift component or plugin.

The language has more built-in facilities than the ECS bridge accepts as component field values. Only the values described in <doc:AdaScriptECS> can cross that bridge safely.
