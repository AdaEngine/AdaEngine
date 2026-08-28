# Ada Script ECS

Declare native ECS queries, select an execution mode, and read or write reflected component fields.

## Plugin and system declarations

An Ada Script manifest has three levels:

```text
AdaPlugin
└── AdaSystem
    └── AdaQuery
```

Create the plugin with a stable name and a list of systems:

```ada
AdaPlugin.create("Gameplay", [movementSystem, lifetimeSystem])
```

Create each system in entity or batch mode:

```ada
AdaSystem.create(identifier, scheduler, queries, instance)
AdaSystem.createBatch(identifier, scheduler, queries, instance)
```

The standard scheduler names are:

- `"startup"`
- `"preUpdate"`
- `"update"`
- `"postUpdate"`
- `"fixedPreUpdate"`
- `"physicsSync"`
- `"physicsStep"`
- `"physicsWriteback"`
- `"fixedUpdate"`
- `"fixedPostUpdate"`

`"update"` is the usual choice for frame-based gameplay. Fixed and physics stages are available when the corresponding AdaEngine scheduler is installed.

## Declare component access

Every query both filters entities and declares scheduler access:

| Declaration | Matches | Allows writes |
| --- | --- | --- |
| `AdaQuery.read(["A", "B"])` | Entities with `A` and `B` | Nothing |
| `AdaQuery.write(["A", "B"])` | Entities with `A` and `B` | `A` and `B` |
| `AdaQuery.readWrite(["A", "B"], ["A"])` | Entities with `A` and `B` | `A` only |

AdaEngine resolves these declarations to native component identifiers during plugin setup. The native scheduler uses the resulting read/write set when checking system conflicts.

Prefer a module-qualified component name if two registered types have the same short name. A short name such as `"Transform"` resolves only when it identifies exactly one registered component.

> Important: Declare every component you access. The bridge never exposes the `World`, and a script cannot use its entity or batch handle to reach undeclared components.

## Use entity mode

`AdaSystem.create` passes a list of entity proxies for each query. This mode is concise and convenient for small sets:

```ada
class DamageSystem {
    func update(deltaTime, queries) {
        var targets = queries[0];

        for (var index in 0..<targets.count) {
            var entity = targets[index];
            var health = entity.get("Health", "value");
            entity.set("Health", "value", health - 1);
        }

        return targets.count;
    }
}

func main() {
    return AdaPlugin.create("Damage", [
        AdaSystem.create("damage.tick", "update", [
            AdaQuery.write(["Health"])
        ], DamageSystem())
    ]);
}
```

An entity proxy exposes:

- `id` — the native entity identifier.
- `get(component, field)` — the reflected field value, or `null` when it cannot be read.
- `set(component, field, value)` — `true` when the write succeeds, otherwise `false`.

## Use batch mode

`AdaSystem.createBatch` creates one proxy per query instead of one proxy per entity. Prefer it for per-frame systems and large entity sets:

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

        return movers.count;
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

An `AdaQueryBatch` exposes:

- `count` — the number of matched entities.
- `id(index)` — the entity identifier, or `-1` for an invalid index.
- `get(index, component, field)` — the reflected field value, or `null`.
- `set(index, component, field, value)` — whether the write succeeded.

Query results appear in the same order as the manifest's query declarations. Empty queries are valid and produce an empty list or a batch whose `count` is zero.

## Bridge component fields

The `@Component` macro generates the reflection metadata used by Ada Script. Register the component before script setup, and use the Swift property name in `get` and `set`.

The following Swift field types have stable mutable bridge representations:

| Swift field | Ada Script value |
| --- | --- |
| `Bool` | `Bool` |
| `Int` | `Int` |
| `Float`, `Double` | `Float` |
| `String` | `String` |
| `Vector2` | Two-number list: `[x, y]` |
| `Vector3` | Three-number list: `[x, y, z]` |
| `Vector4` | Four-number list: `[x, y, z, w]` |
| `Quat` | Four-number list: `[x, y, z, w]` |
| `Color` | Four-number list: `[red, green, blue, alpha]` |
| `EditorEnumReflectable` | Case-name string |

Writes validate the entire value before mutating the component. Integers must convert exactly to Swift `Int`. Floating-point values must be finite, and values written to `Float`-backed fields must fit in the `Float` range. Vector, quaternion, and color lists must have the exact expected length and valid members.

A `set` call returns `false` when:

- The component is not writable in the query.
- The component or field is not declared or reflected.
- The field is read-only.
- The value has the wrong shape or type.
- A numeric value is non-finite or out of range.

Some failures also append a message to ``GravityScriptPlugin/diagnostics``. Treat a `false` result as a rejected write even when no diagnostic is added.

## Use multiple queries

One system can combine differently filtered entity sets. Each query keeps its own access capabilities:

```ada
class TargetingSystem {
    func update(deltaTime, queries) {
        var players = queries[0];
        var enemies = queries[1];

        // Read players and update only enemy Target fields.
        return [players.count, enemies.count];
    }
}

func main() {
    return AdaPlugin.create("Targeting", [
        AdaSystem.createBatch("targeting", "update", [
            AdaQuery.read(["Player", "Transform"]),
            AdaQuery.readWrite(
                ["Enemy", "Transform", "Target"],
                ["Target"]
            )
        ], TargetingSystem())
    ]);
}
```

Ada Script currently exposes component field access, not structural ECS operations. Spawn or despawn entities, add or remove components, and work with resources or events from native Swift systems and plugins.
