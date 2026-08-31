# Ada Script ECS

Declare annotation-driven systems and iterate native AdaECS component columns.

## Declare a system

Apply `@system` to a class and implement `update(context)`:

```ada
@system(scheduler: "update", id: "game.movement")
class MovementSystem {
    func update(context) {
    }
}
```

The scheduler defaults to `update`. System identifiers must be unique within a
script module.

## Declare a query

Apply `@query` to a stored system property:

```ada
@query(
    Health,
    Movement,
    with: Movable,
    without: Frozen
)
var entities;
```

Positional components are fetched and available on each row. `with` and
`without` only filter matching archetypes.

Aliases use lower-camel-case component names:

```ada
for (var entity in entities) {
    var position = entity.movement.position;
    entity.health.current -= 1.0;
}
```

`entity.id` exposes the native entity identifier.

## Iterator behavior

Ada Script queries are native iterators. AdaECS resolves matching archetypes,
binds component columns when entering a chunk, and advances their pointers by
row stride. The bridge does not create an entity proxy for every result and
does not perform a world component lookup for every field access.

A query row and its component views are borrowed. Do not retain them after the
loop or system update returns. Structural changes must use deferred commands.

Inactive entities are skipped. Empty queries execute zero loop iterations.

## Component fields

The `@Component` Swift macro generates the runtime field accessors used by Ada
Script. Register native components before the script plugin is set up.

Supported field values include booleans, integers, finite floating-point
values, strings, vectors, quaternions, colors, and reflected enums. A rejected
write leaves the component unchanged and appends a development diagnostic.

## Access planning

The current implementation conservatively declares write access for fetched
components. This keeps scheduling correct while compiler-level read/write
inference is completed. Filter-only components do not receive write access.

The intended final behavior derives read and write sets from row field usage,
with explicit `@access` metadata as the escape hatch for dynamic code.

## Multiple queries

One system may declare multiple independent iterators:

```ada
@system(scheduler: "update")
class TargetingSystem {
    @query(Player, Transform)
    var players;

    @query(Enemy, Target, without: Dead)
    var enemies;

    func update(context) {
        for (var enemy in enemies) {
            for (var player in players) {
                enemy.target.entity = player.id;
                break;
            }
        }
    }
}
```

Queries are refreshed by the scheduler before each system execution.
