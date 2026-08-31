# ADR-0004: Expose world capabilities, not the raw World

- Status: Accepted
- Date: 2026-08-31
- Implementation: Planned

## Context

Ada Script systems and scriptable objects need to spawn and despawn entities,
insert and remove components, access resources, send events, and use selected
engine services. Exposing the raw Swift `World` would let scripts bypass
scheduler access declarations, mutate archetypes during pointer iteration, and
retain unsafe references across VM calls.

At the same time, an API that cannot perform structural world operations is not
sufficient for gameplay code.

## Decision

Ada Script receives a capability-scoped `WorldContext`. It is not the Swift
`World` object and does not provide unrestricted dynamic lookup.

```ada
func update(context) {
    context.world.commands.despawn(entity.id);
}
```

### Declared data access

World data is available through declared capabilities:

- components through `@query` or `@component`;
- resources through `@res`;
- incoming events through `@events`;
- outgoing events through `@eventWriter`;
- assets through an explicit asset capability;
- UI mounting and dismissal through an explicit UI capability;
- structural changes through `context.world.commands`.

Query and access inference semantics are defined by
[ADR-0002](0002-ada-script-ecs-query-api.md). Script-defined component and
resource identities are defined by
[ADR-0003](0003-ada-script-components-and-resources.md).
AdaUI views and their detached data-flow boundary are defined by
[ADR-0006](0006-ada-script-adaui-integration.md).

The context may expose non-component entity facts whose reads do not hide ECS
access, such as validating an entity identifier. It does not provide an
unrestricted `get(entity, dynamicComponentName)` API.

When dynamic component access is necessary, the containing system must declare
an explicit `@access` set. The runtime verifies each operation against that set.

### Deferred structural commands

Normal update systems enqueue structural mutations:

```ada
context.world.commands.spawn([
    Transform(position: [0.0, 0.0, 0.0]),
    Health(current: 100.0)
]);

context.world.commands.insert(
    entity.id,
    Poison(duration: 5.0)
);

context.world.commands.remove(entity.id, Poison);
context.world.commands.despawn(entity.id);
context.world.commands.mountUI(GameHUD(), behaviour: "overlay");
```

Commands are applied after the active system scope, when no script query row or
component pointer can be invalidated by an archetype change. A system using
commands declares deferred world access to the scheduler.

Command arguments are detached values. Borrowed query rows and component views
cannot be stored inside commands.

### Exclusive startup and tooling access

An explicit exclusive capability may be used for bootstrap and editor tooling:

```ada
@system(scheduler: "startup")
@exclusiveWorld
class BootstrapSystem {
    func update(context) {
        context.world.insertResourceImmediate(GameSettings());
        context.world.spawnImmediate([InitialSceneTag()]);
    }
}
```

An exclusive world system:

- cannot run concurrently with another system;
- cannot perform immediate structural mutation while a query iterator is active;
- is intended for startup, migration, loading, and tooling rather than frame
  gameplay;
- still receives a checked `WorldContext`, not the raw Swift object.

The initial implementation may ship deferred commands before the exclusive
escape hatch. The capability boundary remains the same.

### Lifetime

`WorldContext`, commands facades, resource views, query rows, and component
views are valid only for the current lifecycle callback. Retaining them in a
script object or global variable is rejected or diagnosed when used.

## Consequences

- Scripts can implement gameplay lifecycle operations without defeating ECS
  scheduling.
- Structural changes do not invalidate the native iterator defined in ADR-0002.
- The scheduler can continue to reason about concrete component, resource, and
  deferred-world access.
- Engine subsystems are exposed as narrow capabilities instead of incrementally
  turning `WorldContext` into a second public `World` API.
- New capabilities require explicit descriptors, access rules, lifetime rules,
  and LSP surface.

## Rejected alternatives

### Expose the Swift `World` through the Gravity bridge

Rejected because it bypasses access tracking, thread-safety, pointer lifetime,
and structural mutation invariants.

### Allow arbitrary dynamic component lookup

Rejected because a system access set must be known before scheduling. Checked
dynamic lookup remains possible only within an explicit declared access set.

### Apply structural mutations immediately in update systems

Rejected because moving an entity between archetypes can invalidate active
chunk and component pointers.
