# Ada Script Language

Use Ada Script syntax with AdaEngine declaration annotations. New to the
language? Start with <doc:AdaScriptBasics> for values, functions, types,
properties, control flow, asynchronous work, and annotations.

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

## Optional strict type checking

Ada Script remains dynamically typed by default. Enable strict checking for a
single source by placing `@strict` before its first declaration:

```ada
@strict

func addScore(score: Int, amount: Int) -> Int {
    return score + amount;
}
```

In an AdaEditor project, **Project Settings → Runtime → Type Checking → Strict**
enables the same analysis for every `.ada` source. The serialized setting is:

```json
{
  "build": {
    "system": "adascript",
    "adaScriptTypeChecking": "strict"
  }
}
```

Strict checking validates annotated assignments, function arguments, member
access, and return values before the module runs. Use `Any` for an intentional
dynamic boundary. Untyped code and projects using `"dynamic"` keep normal
Ada Script runtime behavior.

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

Three import forms exist:

```ada
import { clampSpeed, MovementSettings as Settings } from "../Shared/Movement";
import * as Combat from "./Combat";
import { Text, VStack } from "AdaUI";
```

- `{ name }` imports a public declaration, and `name as Local` renames it for
  the importing file.
- `* as Alias` makes `Alias.name` refer to a public declaration of that file.
- `"AdaEngine"` and `"AdaUI"` are built-in modules. `AdaUI` has a closed list
  of views and rejects any other name. `AdaEngine` provides the script-facing
  services (`Input`, `Assets`, `Math`, `Vector3`, ...) and also accepts the
  components and resources the host registers at runtime, so those names are
  not checked statically.
- `"@library.id/path"` imports from a restored library.

A declaration is public unless written `private`. A private declaration is
module-local: importing it, or reaching it through a namespace, is an error, and
so is importing a name the file does not declare. Gravity compiles a module as
one global scope, so a name declared by two reachable files cannot coexist; the
duplicate is reported with both file names instead of being shadowed. Qualifying
a name with a namespace checks that it is exported but does not create a separate
scope. Imports are resolved by one parser and one set of path rules shared by the
runtime, the build generator, and the Editor, which also reports each import
cycle in full on every import that closes it and completes names inside
`import { | } from "module"`.

## Annotations

Ada Script declaration annotations have three forms:

```ada
@name
@name(value)
@name(key: value, other: [a, b])
```

Arguments are compile-time constants or symbolic identifiers. They do not run
user code during module discovery.

See <doc:AdaScriptAnnotations> for supported annotations, declaration targets,
arguments, defaults, and lifetimes. An annotation the engine does not define, or
one placed on a target it does not support, is a compile error carrying the
file, line and column of the annotation. A one-time world initializer is a
`@system(scheduler: "startup")` class with `update(context)`; there is no
function-level `@init` annotation yet.

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

Component and resource fields may also be vectors, colors, enumerations, entity
references, and asset paths. The declared type selects the kind and the default
must match it:

```ada
enum Mode { idle, moving }

@component(id: "game.body", aliases: ["OldBody"])
struct Body {
    @export var position: Vector3 = Vector3(0, 1, 0);   // Vector2, Vector3, Vector4, or [x, y, z]
    @export var tint: Color = Color(1, 0.5, 0);          // Color(r, g, b[, a]), Color.white / black / clear
    @export var mode: Mode = Mode.idle;                  // stored as the case name, "idle"
    @export var target: Entity = null;                   // an entity id, -1 when unassigned
    @export var icon: Asset = "@res://Icons/body.png";   // a project asset path, or null
}
```

Scripts read and write these as lists (`row.body.position[0]`,
`row.body.position = [1.0, 2.0, 3.0]`) and strings; a write with the wrong length,
a non-finite number, or an unknown enum case is rejected and leaves the field
unchanged. These field kinds are not allowed in network fields. `aliases` keeps
scenes saved under a former name loadable: scenes are stored under the stable ID,
and `AdaScriptSceneSchemaResolver` reports a scene that still uses an alias,
fields that were removed, and values of the wrong type.

Generated Swift symbol names are private implementation details. Runtime lookup
accepts both the Ada Script declaration name (`Health`) and the stable ID
(`game.health`). `autoInsert: true` inserts the resource before systems are
installed. SwiftPM targets use generated backing types; AdaEditor can register
supported runtime-defined component layouts for pure AdaScript projects.

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

A `@res` binding requests the scheduler access its use needs. It is read-only
when every use is a field read (`balance.acceleration`, `balance.available()`);
assigning a field, or any use that could alias the binding such as passing it or
storing it in another variable, requests write access. State the access
explicitly with `@res(access: "read")` or `@res(access: "write")`; declaring
`"read"` for a binding the system writes is a compile error. Two systems that only
read a resource may run at the same time.

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
mutation. Typed component constructors, including field overrides, can be passed
to `context.world.spawn([...])`, `commands.spawn([...])`, and
`commands.insert(entity, Component(...))`; the string-based form remains
available.

### Dynamic access with `@access`

A system that needs to read or write a component by name, without declaring a
query, lists the components up front:

```ada
@system(id: "poison.tick")
@access(read: [Health], write: [Poison])
class PoisonTick {
    func update(context) {
        var duration = context.world.read(entityID, "Poison", "duration");
        context.world.write(entityID, "Poison", "duration", duration - 1);
        context.world.has(entityID, "Health");
    }
}
```

The declaration is added to the system's scheduler access, so the system never
runs concurrently with a conflicting one. Reading or writing a component outside
the set, or writing a read-only component, reports a diagnostic and does nothing.
Without `@access`, `read`, `write` and `has` are rejected.

### Events

`@eventWriter(Name)` and `@events(Name)` bind an event writer and the received
events of one name to a system property:

```ada
@system(id: "trap")
class Trap {
    @eventWriter(Damage)
    var damage;

    func update(context) {
        damage.send(["amount", 5, "source", "trap"]);
    }
}

@system(id: "health")
class Health {
    @events(Damage)
    var hits;

    func update(context) {
        for (var hit in hits) {
            var amount = hit.value.amount;
        }
    }
}
```

The payload is a flat list of alternating field names and primitive values, which
keeps every queued value detached from the VM. A reader sees the events written
during the previous frame. Events require `EventsPlugin` (installed by the default
plugins); a system that declares them without it fails to install.

### Exclusive world access

`@exclusiveWorld` marks a system that may change world structure immediately,
intended for startup, loading and tooling:

```ada
@system(id: "bootstrap", scheduler: "startup")
@exclusiveWorld
class Bootstrap {
    func update(context) {
        var entity = context.world.spawnImmediate([Transform()]);
        context.world.insertImmediate(entity, "game.player");
        context.world.removeImmediate(entity, "game.player");
        context.world.despawnImmediate(entity);
    }
}
```

An exclusive system never runs alongside another system. An immediate operation
is rejected while one of the system's query iterators is still active.
Immediate resource insertion is not available yet.

SwiftPM generation of native backing types requires `AdaScriptBuildPlugin`;
supported pure AdaScript layouts can be registered by the runtime.

Swift and Editor tooling can attach the generated default without naming its
private backing type:

```swift
world.insertDefaultComponent(named: "game.health", into: entity.id)
```

Field types and serialization support vary by schema and bridge. Check the
nearest compiler diagnostic when a constructor argument or field default is
unsupported.

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
objects intentionally have no user-interface callback; compose interfaces in
Swift with AdaUI.

## Multiplayer schemas

Use a typed command for peer intent. Field tags, rather than declaration order
or source names, define the wire schema:

```ada
@network_command(
    id: "game.player-input",
    delivery: "unreliable_sequenced",
    channel: "input"
)
struct PlayerInput {
    @network_field(1) var moveX = 0.0;
    @network_field(2) var moveY = 0.0;
    @network_field(3) var attackSequence = 0;
}
```

Peers send the generated value through the scoped multiplayer resource. Host
systems receive typed values and an authenticated transport source:

```ada
@system
class InputSystem {
    @res var multiplayer: Multiplayer;
    @remote_commands(PlayerInput) var inputs;

    func update(context) {
        multiplayer.send(PlayerInput(1.0, 0.0, 4));
        for (var message in inputs) {
            var peer = message.source;
            var movement = message.value.moveX;
        }
    }
}
```

The runtime owns packet sequences and command envelopes. `message.source`
cannot be supplied by script payload data. Swift and AdaScript declarations
with matching IDs, versions, tags, types, direction, delivery, and channel
produce the same compatibility schema.

`@replicated_component` uses `@network_field` plus optional `@local` fields.
SwiftPM targets receive a generated native ECS backing component through
`AdaScriptBuildPlugin`. Portable AdaEditor projects register each component as
a distinct runtime ECS layout without compiling Swift.

`@rpc` declares both a typed wire command and an optional receiver method:

```ada
@system class InputSystem {
    @res var multiplayer: Multiplayer;
    @res var playerInput: PlayerInputState;

    @rpc(id: "arena.input", delivery: "unreliable_sequenced", channel: "input")
    func input(@network_field(1) moveX = 0.0, @network_field(2) attack = 0) {
        playerInput.peer = source;
        playerInput.moveX = moveX;
        playerInput.attack = attack;
    }

    func update(context) {
        multiplayer.send(input(1.0, 2));
    }
}
```

Calling `input(...)` constructs a typed command; `multiplayer.send(...)` sends
it. The authored body does not run on the sender. On receipt, the system invokes
it before `update`, with `source` bound to the authenticated transport peer ID.
Fields remain tagged and require constant defaults. An empty or bodyless method
still works as a command constructor; `@remote_commands(input)` remains available
for explicit message processing. Request/response and local echo are not yet
supported.

## Asynchronous work

Declare a function that can suspend with `async func`. Use `await` inside that
function; a synchronous action starts it explicitly with `Tasks.start(...)`.
The action returns immediately while the game or UI continues updating.

```ada
async func loadShop() {
    var result = await Assets.loadAsync("@res://Catalog/shop.json");
    if (result.isSuccess()) {
        System.print("Shop asset: " + result.value());
    } else {
        System.print(result.errorCode() + ": " + result.message());
    }
}

@system class ShopSystem {
    var started = false;

    func update(context) {
        if (!started) {
            started = true;
            Tasks.start(loadShop());
        }
    }
}
```

`Assets.loadAsync` and `Assets.saveAsync` use the native asset registry and
return an awaitable result. `Saves.writeAsync("@user://save.txt", text)` writes
an immutable string in the background and reports `committed()` after its
atomic file replacement. For data that cannot be copied in one callback, use
bounded chunks:

```ada
async func saveLargeData() {
    var writer = Saves.begin("@user://save.txt");
    var first = await writer.appendAsync("first chunk");
    if (!first.isSuccess()) { writer.cancel(); return; }
    var committed = await writer.finishAsync();
    if (!committed.committed()) { System.print(committed.message()); }
}
```

Each chunk is limited to 256 KiB. The writer appends to a temporary file and
replaces the destination only after `finishAsync()` succeeds. Build large ECS
snapshots in bounded pieces; do not retain a query row or live component view
in a task.

Mark a script-owned type with `@nonsendable` when its instances are tied to a
callback or another short lifetime. AdaScript rejects a typed async parameter
or method that would capture that type. Before a task starts, the runtime also
checks actual arguments, nested lists, returned values, and promise results;
this catches borrowed engine values passed through an untyped alias. Maps are
conservatively rejected until their entries can be inspected. See
<doc:AdaScriptAnnotations>.

`await Time.sleep(seconds)` advances with the scheduler's `deltaTime` and stops
advancing when that scheduler is paused. AdaEngine does not yet expose a
separate game time-scale resource.
`await Time.sleepRealTime(seconds)` uses a monotonic clock; continuation still
waits for a script dispatch point. `Tasks.promise()` creates a one-shot wait
that another script callback can resolve with `complete(value)`.
`Tasks.start(...)` returns a handle with `status()` and `cancel()`.

AdaScript callbacks such as `update(context)` remain synchronous. Do not mark
them `async`; start a separate async function and pass
detached values. Callback contexts, queries, resources, and commands expire at
callback exit. Awaited work resumes in the serialized script runtime, not on
the native I/O worker. Cancelling a save does not roll back
a file that was already committed.

Fallible operations return a result with `isSuccess()`, `value()`,
`errorCode()`, and `message()`; inspect it after `await`. A script VM trap
currently stops that module and cancels its pending tasks. Diagnostics include
the failing task, owner, and trace ID; reload the module to continue. Other
module instances and native gameplay remain separate.

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

## Common language patterns

The syntax primer in <doc:AdaScriptBasics> covers functions, conditions,
loops, structs, classes, static members, initializers, and accessors. In an ECS
system, use those language features together with query bindings:

```ada
func clampHealth(value, maximum) {
    if (value < 0) { return 0; }
    if (value > maximum) { return maximum; }
    return value;
}

@system
class DamageSystem {
    @query(Health, without: Invulnerable)
    var targets;

    func update(context) {
        for (var target in targets) {
            target.health.current = clampHealth(target.health.current - 1, 100);
        }
    }
}
```

Functions called by a system are ordinary helpers; they do not become
scheduler callbacks. A system's `update(context)` is the entry point selected
by `@system`. A scriptable object's `ready(context)` instead belongs to that
entity's attachment lifecycle. For one-time world setup, use the `startup`
scheduler described in <doc:AdaScriptAnnotations>.

An `import { name } from "./Helpers";` brings a helper into the target-level
module. Importing a file does not create a second world or a second run of its
systems. A library can contribute its own annotated declarations; keep IDs
unique across the assembled module. See <doc:AdaScriptLibraries>.

## Values crossing the bridge

Ada Script bridge values are detached booleans, integers, finite floating-point
numbers, strings, lists, and null. ECS component views are borrowed native
capabilities rather than detached values.

Unsupported values and invalid numeric conversions are rejected without
partially mutating a component.

System `update(context)` callbacks are command-style. Their return values are
ignored; observable behavior belongs in components, resources, events, or
diagnostics.
