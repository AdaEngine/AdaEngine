# ADR-0004: Expose world capabilities, not the raw World

- Status: Accepted
- Date: 2026-08-31
- Implementation: Partial (commands, events, `@access`, `@exclusiveWorld`, LSP shipped; asset and UI capabilities open)

## Implementation status

Last verified: 2026-10-14.

Shipped:

- [x] `update(context)` receives a checked `WorldContext` facade rather than a
  Swift `World` reference.
- [x] Direct `context.world.commands` use is detected per system by
  `AdaScriptCompilerCore` and adds deferred-world access to `SystemAccessSet`.
- [x] `spawn`, `insert`, `remove`, and `despawn` enqueue native AdaECS
  `Commands`; mutations are applied after query parameters finish.
- [x] Spawned and inserted component defaults are resolved by declaration name
  or stable ID and detached from the Gravity VM before enqueueing.
- [x] Retained command facades are invalidated after `update(context)` and
  rejected when used later.
- [x] Runtime validation rejects command access that was not granted by static
  capability inference.

- [x] Component constructor expressions and field overrides become detached
  native payloads for `spawn` and `insert`, through one shared decoder
  (`AnnotatedGravityComponentPayloads`) used by deferred and immediate paths.
  `remove` accepts a stable component name.
- [x] `@access(read: [...], write: [...])` on an `@system` class resolves each
  component, adds it to the system's scheduler access, and gates the dynamic
  `context.world.read`, `write` and `has` calls. Calls outside the declared set,
  writes to a read-only component, and any call without `@access` are rejected
  with a diagnostic.
- [x] `@eventWriter(Name)` and `@events(Name)` bind a writer and the previous
  frame's events of one name to a system property. Events are native
  `AdaScriptRuntimeEvent` values with detached primitive fields in
  `EventsStorage`; a system declaring them without `EventsPlugin` fails to
  install instead of crashing.
- [x] `@exclusiveWorld` adds `ExclusiveWorldAccess` to the system, which
  `SystemAccessSet.isCompatible` treats as incompatible with every other system.
  `spawnImmediate`, `insertImmediate`, `removeImmediate` and `despawnImmediate`
  apply at once and are rejected for non-exclusive systems and while one of the
  system's query iterators is active.
- [x] The Editor language service offers `events`, `eventWriter`, `exclusiveWorld`
  and the new `context.world` members, and reports: capability annotations on a
  non-system target, malformed event names, immediate operations without
  `@exclusiveWorld`, dynamic access without or outside `@access`, and storing
  `context.world` in a property or global (lifetime).

Remaining before this ADR is implemented:

- [ ] Asset capability. `Assets` is still a VM-wide service available to every
  system; making it an explicit per-system capability would break existing
  scripts and needs a migration decision.
- [ ] UI capability (`mountUI`). Blocked: AdaUI views in AdaScript are disabled
  ("temporarily unavailable"), so there is nothing to mount.
- [ ] `insertResourceImmediate`. Blocked on ADR-0003: resources have no
  type-erased constructor, so a script cannot yet create one by name.

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

The first implementation accepts stable component names and creates their
registered defaults. This keeps every queued value detached from the VM while
the schema-value encoder is still pending:

```ada
var projectile = context.world.commands.spawn([
    "game.transform",
    "game.projectile"
]);

context.world.commands.insert(projectile, "game.damage");
context.world.commands.remove(projectile, "game.damage");
context.world.commands.despawn(projectile);
```

Component arguments may also be constructor expressions with field overrides,
for example `commands.insert(entity, Poison(duration: 5.0))`; both forms produce
detached native values. Capability inference currently recognizes direct
`context.world.commands` access. An indirect alias that bypasses inference is rejected by the runtime
instead of receiving undeclared world access.

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
