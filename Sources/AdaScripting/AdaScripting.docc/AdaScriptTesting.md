# Testing Ada Script

Write tests next to your gameplay code, run them with `swift test` or a command, and keep them out of shipped builds.

## Overview

A function annotated with `@test` is a test. It takes no parameters and may sit in any `.ada` file, where it can see that file's `private` declarations, or under a `Tests/` directory, where it sees public declarations only.

```ada
@system(id: "gravity")
class GravitySystem {
    @query(Body)
    var bodies;

    func update(context) { /* … */ }
}

private func clampSpeed(speed) { return Math.max(speed, -50.0); }

@test("speed is capped")
func speedIsCapped() {
    expectEqual(clampSpeed(-100.0), -50.0);
}
```

### Assertions

`expect(condition)`, `expectEqual(actual, expected)`, `expectNear(actual, expected, tolerance)`, `expectNil(value)` and `fail(message)` record a failure and let the test continue. `require(condition)` records a failure and ends the test. Each failure is reported as `path:line:column: message`.

### TestWorld

`TestWorld()` creates an isolated world with the module's components and systems. Time moves only when the test says so.

Run synchronous `TestWorld` steps on the host. Browser players cannot block their
single thread while awaiting the scheduler; they report a diagnostic if asked to
step a test world. Gameplay systems continue through the normal async frame loop.

```ada
@test("a body falls")
func falls() {
    var world = TestWorld();
    var body = world.spawn([Body(y: 10.0, speed: 0.0)]);
    world.run(30);
    expect(world.read(body, "Body", "y") < 10.0);
}
```

- `spawn(components)`, `insert(entity, component)`, `remove(entity, name)` and `despawn(entity)` change entities at once.
- `has(entity, name)`, `read(entity, name, field)` and `count(name)` inspect them.
- `run(ticks)` installs every system and runs fixed 1/60 s ticks. `runSystem(System, ticks)` installs only that system. `advance(seconds)` runs one step of an exact length.

Each test gets its own world. Module-level `var` values that are numbers, booleans, strings or null are restored after each test; lists and maps are not.

### The Tests directory

Files under `Tests/` are compiled only when tests run, and gameplay code cannot import from them.

### Running tests

Load a project with tests and run it from Swift:

```swift
let plugin = try AdaScriptPlugin(sources: sources, name: "Game", includeTests: true)
let results = plugin.runTests()
```

or point ``AdaScriptTestProject`` at a directory, which picks up every `.ada` file, and render the outcome with ``AdaScriptTestReport`` as text, JUnit or JSON. The `AdaScriptTest` command does the same from a terminal and exits non-zero on failure:

```
swift run AdaScriptTest Path/To/Project --format junit
```

Production modules never contain tests. Loading without `includeTests` removes every `@test` function and the `Tests/` directory, and reports any gameplay code that refers to a test-only name such as `expect` or `TestWorld`.

## Topics

### Running tests

- ``AdaScriptTestProject``
- ``AdaScriptTestReport``
- ``AdaScriptTestCase``
- ``AdaScriptTestResult``
