# AdaScript gameplay recipes

Short, working patterns for input, movement, spawning, collisions, score, restart and sound in AdaScript games.

The complete game that uses all of them is the bundled example `side-scroller-3d`: a 3D side-scroller in about twenty small files with a scene, a HUD, sounds and tests. In Web Studio, inspect the current project with `editor_project_files`, `editor_file_read` and `editor_scene_get`. Blocks marked `// recipe` below are compiled by Studio's test suite, so they are safe to copy. Studio's pure AdaScript projects accept `@resource` structs, bound with `@res`; the example nevertheless keeps shared data (round state, intent, cues) in `@component` structs on one "Game" entity in the scene, read with `@query`, so the scene can author it and tests can read it. Syntax follows ADR-0001 to ADR-0003 (annotations and modules, ECS queries, components and resources); see <doc:AdaScriptECS> and <doc:AdaScriptLanguage>.

## Lay the game out in files

One responsibility per file, grouped by layer: `Config.ada` (all balance numbers), `Rules.ada` (pure functions), `Components/` (data only), `Systems/` (one `@system` per file), `UI/`, `Tests/`. Import across files with `import { Name } from "./Path.ada";`. Systems are ordered with `@before(id:)` and `@after(id:)`. Do not write a game as one file.

```ada
// recipe
class Config {
    static var gravity = 22.0;
    static var flapSpeed = 7.5;
}

class Rules {
    static func fall(velocity, dt) { return velocity - Config.gravity * dt; }
}

@test("gravity pulls down")
func gravityPullsDown() {
    expect(Rules.fall(0.0, 0.1) < 0.0);
}
```

## Input

Declare actions (name and bindings such as Space, left mouse button, touch) in project settings; they are stored in `.ada/project.json`. Bind the `Input` resource in exactly one system (`@res(optional: true)` with an `available()` check, so tests can run it without `Input`) and publish what the player asked for as a component on the Game entity. The other systems read that component, which keeps them testable because tests have no `Input`.

```ada
// recipe
@component(id: "recipes.intent")
struct Intent {
    @export var flap = false;
    @export var move = 0.0;
}

@system(id: "recipes.input")
class InputSystem {
    @res(optional: true) var input: Input;
    @query(Intent) var intents;

    func update(context) {
        if (!input.available()) return;
        for (var game in intents) {
            game.intent.flap = input.isActionJustPressed("Flap");
            game.intent.move = input.getActionStrength("MoveRight") - input.getActionStrength("MoveLeft");
        }
    }
}
```

`isActionPressed` is true while held, `isActionJustPressed` and `isActionJustReleased` are single-frame transitions, `getActionStrength` is 0 to 1. Action names are case sensitive; an unknown name is false or zero.

## Movement and gravity

Components hold state; the position is the entity's `Transform`. Read `position` as a list and write a whole list back. Scale all motion by `context.deltaTime`, clamped so a long frame cannot skip over a collision.

```ada
// recipe
class Tuning {
    static var gravity = 20.0;
}

@component(id: "recipes.body")
struct Body {
    @export var velocity = 0.0;
}

@system(id: "recipes.fall")
class FallSystem {
    @query(Body, Transform) var bodies;

    func update(context) {
        var dt = Math.clamp(context.deltaTime, 0.0, 0.05);
        for (var row in bodies) {
            row.body.velocity -= Tuning.gravity * dt;
            var position = row.transform.position;
            row.transform.position = [position[0], position[1] + row.body.velocity * dt, position[2]];
        }
    }
}

@test("a body falls")
func bodyFalls() {
    var world = TestWorld();
    var body = world.spawn([Body(), Transform(position: [0.0, 5.0, 0.0])]);
    world.runSystem(FallSystem, 30);
    expect(world.read(body, "Body", "velocity") < 0.0);
}
```

Put balance numbers in a `Config` class (`static var`), never in the systems.

## Spawning and removing entities

Structural changes go through `context.world.commands` and are applied after the system finishes. `spawn([...])` takes component constructors; `despawn(entity.id)` removes an entity. A query row is borrowed: use it inside the loop, do not store it.

```ada
// recipe
@component(id: "recipes.shot")
struct Shot {
    @export var life = 0.6;
}

@component(id: "recipes.spawner")
struct Spawner {
    @export var left = 0.0;
}

@system(id: "recipes.spawn")
class SpawnSystem {
    @query(Spawner) var spawners;

    func update(context) {
        var fire = false;
        for (var row in spawners) {
            row.spawner.left -= context.deltaTime;
            if (row.spawner.left <= 0.0) {
                row.spawner.left = 0.25;
                fire = true;
            }
        }
        if (fire) { context.world.commands.spawn([Transform(position: [0.0, 0.0, 0.0]), Shot()]); }
    }
}

@system(id: "recipes.expire")
class ExpireSystem {
    @query(Shot) var shots;

    func update(context) {
        for (var row in shots) {
            row.shot.life -= context.deltaTime;
            if (row.shot.life <= 0.0) { context.world.commands.despawn(row.id); }
        }
    }
}

@test("shots appear and expire")
func shotsComeAndGo() {
    var world = TestWorld();
    world.spawn([Spawner()]);
    world.run(30);
    expect(world.count("Shot") > 0);
    expect(world.count("Shot") < 5);
}
```

Mesh and material components cannot be constructed from a script, so anything with a visible 3D mesh is authored in the scene. Scroll a **pool** of scene entities and reuse them instead of spawning: when an obstacle leaves the screen, move it to the back of the line and give it a new gap (`ObstacleSystem` in the example). Spawn and despawn suit logic-only entities and entities built from components a script can construct.

## Collisions and scoring

Keep the geometry in a pure function and the reaction in a system. For a side view, test the circle or box against columns in x and y. Score a column once, with a `passed` flag on the obstacle component, and raise a cue for sound.

```ada
// recipe
class Hit {
    // True when a circle at (x, y) with radius r touches a circle at (cx, cy) with radius cr.
    static func circles(x, y, r, cx, cy, cr) {
        var dx = x - cx;
        var dy = y - cy;
        var reach = r + cr;
        return dx * dx + dy * dy <= reach * reach;
    }
}

@test("circles touch only when close")
func circlesTouch() {
    expect(Hit.circles(0.0, 0.0, 1.0, 1.5, 0.0, 1.0));
    expect(!Hit.circles(0.0, 0.0, 1.0, 3.0, 0.0, 1.0));
}
```

Two queries in one system can be nested (`for (var a in as) { for (var b in bs) { ... } }`). Pass numbers into functions, not rows.

## Phases, game over and restart

Store the round in a component on the Game entity: `phase` (ready, playing, over), `score`, `best` and a `resetRequested` flag. One system changes the phase from the intent; another system performs the reset when the flag is set (positions, velocities, score, flags), then clears the flag. A reset flag that starts `true` also places everything on the first frame. Gameplay systems return early unless the phase is playing.

## Sound with AudioSource

Create the sound with `editor.audio.generate`, add one entity per sound in the scene with an `AudioSource` (`source: "@res://Audio/flap.wav"`) and a small marker component carrying the cue name. Systems raise a cue flag in a component on the Game entity; one audio system sets `audioSource.play = true` on the matching entity and clears the cues. The engine clears `play` itself. Use one entity per sound that can overlap itself, because a second `play` restarts the first.

```ada
// recipe
@component(id: "recipes.cue-name")
struct CueName {
    @export var name = "";
}

@component(id: "recipes.cues")
struct Cues {
    @export var hit = false;
}

@system(id: "recipes.audio")
class AudioSystem {
    @query(Cues) var games;
    @query(AudioSource, CueName) var sounds;

    func update(context) {
        var hit = false;
        for (var game in games) {
            hit = game.cues.hit;
            game.cues.hit = false;
        }
        for (var row in sounds) {
            if (row.cueName.name == "hit" && hit) { row.audioSource.play = true; }
        }
    }
}

@test("a hit cue plays the matching sound")
func hitPlaysSound() {
    var world = TestWorld();
    world.spawn([Cues(hit: true)]);
    var sound = world.spawn([AudioSource(source: "@res://Audio/hit.wav"), CueName(name: "hit")]);
    world.runSystem(AudioSystem, 1);
    expect(world.read(sound, "AudioSource", "play"));
}
```

## HUD

Author the HUD as a `.ui` file with string inputs, add a `UIComponent` entity that points to it, and bind each input to an exported field of a `@scriptable` class with `scriptBindings`. A scriptable can bind a script-defined `@component` with `@component var state: GameState;` and read it in `update(context)`. The example instead has one system write the text into a small `static var` presentation model (`HudModel`) that the scriptable copies into its exported fields. Gameplay never reads the model. Keep the wording in a pure function so tests can check it.

## Test the game without a window

`TestWorld()` creates an isolated world with the module's systems; `run(ticks)` runs fixed 1/60 s ticks, `advance(seconds)` runs one step, `read(entity, "Component", "field")` and `count("Component")` inspect it. It has no `Input` resource, so bind `Input` optionally in the input system and press keys by replacing the intent component: `world.insert(game, Intent(flap: true))`, run one tick, then insert a fresh `Intent()`. A test cannot read resources, so keep data a test must check in components. `Tests/RoundTests.ada` in the example does this for the whole round: start, flap, fall, game over, restart, scoring and sound.
