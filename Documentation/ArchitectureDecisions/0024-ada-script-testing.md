# ADR-0024: Test Ada Script with `@test` functions and an isolated `TestWorld`

- Status: Proposed
- Date: 2026-10-14
- Implementation: Partial (timeout and Studio test run shipped; results panel, stripping pass and parameterized tests remain; not released)

## Implementation status

Last verified: 2026-10-16.

Shipped on `feat/ada-script-tests` (not released):

- [x] `@test` in `AdaScriptAnnotationCatalog` and annotation discovery; a test with parameters is diagnosed.
- [x] Production resolution strips `@test` functions and rejects production references to test-only names
  (`includeTests` keeps them).
- [x] `expect`, `expectEqual`, `expectNear`, `expectNil`, `fail` and `require` record `path:line:column`
  diagnostics. `AdaScriptTestLowerer` adds the call-site location, and `require` ends the test's fiber with
  `Fiber.yield()`; `Fiber.abort` also ends the caller, so it is not used.
- [x] `TestWorld()`: a fresh ECS `World` per test, driven by a manual clock. Scripts get `spawn`, `insert`, `remove`,
  `despawn`, `has`, `read`, `count`, `run(ticks)`, `runSystem(System, ticks)` and `advance(seconds)`. `run` and
  `advance` block the test thread until the async scheduler finishes, releasing the VM lock meanwhile so script
  systems can run on the scheduler's threads.
- [x] `AdaScriptPlugin(includeTests: true).runTests(matching:)` returns structured `AdaScriptTestResult`s; each test
  runs in its own fiber, so a runtime error fails only that test.
- [x] `Tests/` source root for integration tests: left out of production modules, loaded with `includeTests`, and
  gameplay code importing from it is diagnosed.
- [x] `AdaScriptTestProject.run(directory:)` loads a project from disk; `AdaScriptTestReport` renders a summary, JUnit
  and JSON. A Swift Testing `@Test(arguments:)` runs every fixture project, so `swift test` covers Ada Script tests.
- [x] `swift run AdaScriptTest <directory> [--filter] [--format text|junit|json]` exits 0, 1 (failures or no tests)
  or 2 (usage or load error).
- [x] DocC article "Testing Ada Script".
- [x] Per-test timeout. `AdaScriptPlugin(includeTests:testTimeout:)` instruments the module with the existing
  checkpoint calls but installs a timeout-only budget: the deadline is reset before each test, and `System`, the VM
  limits and spawns stay unrestricted. A runaway test fails with `<name>: test timed out after N seconds` and the
  next test still runs. The limit is cooperative (function entries and loop iterations); a single long native call is
  not interrupted, and a script system that resets the budget while the test waits in `run` or `advance` restarts the
  clock. `AdaScriptTestProject.run(sources:name:matching:testTimeout:onResult:)` exposes it with a per-test callback.
- [x] Editor integration for AdaScript projects: `editor.test.start` and the Run Tests command load the source root and
  `Tests/` with project-relative paths, run in process (no SwiftPM, default 30 s per test), stream `PASS`/`FAIL`
  lines with `path:line:column: message` to the Output panel, and report passed/failed/total in `editor.task.status`.
  A project with no `@test`, or a filter matching nothing, is refused or fails rather than passing.

Differences from the Decision text, taken deliberately:

- `TestWorld` has no `get` and no `flush`. A test reads a field with `read(entity, "Component", "field")`, and spawn
  and despawn on a test world are immediate, so there is nothing to flush.
- Module-level variables are **restored** after each test instead of failing the test on a difference. A system under
  test legitimately keeps state in a global (a "spawned" flag, a counter), so failing would make such systems
  untestable. Only numbers, booleans, strings and null are restored; lists and maps are references and are not.
- A startup system runs once, on the first step after it is installed. A startup system installed later through
  `runSystem` after the first step does not run.

Remaining before this ADR is implemented:

- [ ] Strip declarations reachable only from tests, and the build generator's own stripping pass.
- [ ] Editor language-service support, run buttons beside each `@test` and a results panel (depends on ADR-0023). Results currently go to the Output panel and the MCP task status.
- [ ] Parameterized tests, and a decision on which Swift plugins a `TestWorld` may install.

## Context

Ada Script has no way to test game logic. Swift tests can load a fixture and
inspect the result, but a script author cannot write a check beside the code it
covers. Godot offers no built-in answer either: the engine uses C++ tests, and
GDScript projects rely on addons (GUT, GdUnit4). Rust and Swift Testing keep
unit tests next to the code, which is the model this ADR follows.

Two existing constraints shape the design:

- A declaration is public unless written `private`, and private names are
  visible only inside their file (ADR-0001). A test in another file would force
  authors to make helpers public only to test them.
- Systems do not receive the Swift `World`; they receive a capability-scoped
  `WorldContext` (ADR-0004). A test world must not weaken that boundary.

## Decision

### Tests are annotated functions

`@test` marks a free function with no parameters. An optional string is the
display name; otherwise the function name is used.

```swift
@system
class GravitySystem { ... }

private func clampVelocity(v) { ... }

@test("clamp caps speed")
func clampCaps() {
    expectEqual(clampVelocity(999), MAX_SPEED)
}

@test("gravity pulls bodies down")
func gravityPullsDown() {
    let world = TestWorld()
    let e = world.spawn(Position(0, 10), Velocity(0, 0))
    world.run(GravitySystem, ticks: 10)
    expect(world.get(e, Velocity).y < 0)
}
```

`@test` is registered in `AdaScriptAnnotationCatalog` with the `.function`
target only. The runtime, build generator and Editor therefore report an
unknown or misplaced `@test` from the same table. Discovery uses the existing
annotation path and never executes a manifest.

### Tests live beside the code, plus an optional `Tests/` root

- **Inline:** `@test` may appear in any `.ada` file. It sees that file's
  `private` declarations, like a Rust `#[cfg(test)]` module.
- **`Tests/`:** every `.ada` file under the project's `Tests/` directory is an
  integration-test source. It is compiled only in the test configuration and
  sees public declarations only, like an external user of the module. The
  directory is excluded from gameplay source collection, as `Tools/` is
  (ADR-0023).

The runner discovers `@test` in both places with the same diagnostics and
filters. A test file may import any public name; a gameplay file may not import
from `Tests/`.

### Isolation unit: `TestWorld`, not a VM per test

All tests of one module share the compiled module and one VM. Each test builds
its own `TestWorld`, and nothing else is reset.

- `TestWorld` wraps a fresh `World` created for that test, with no plugins
  beyond those the test installs. It is destroyed when the test returns.
- It is not the production `WorldContext`. It exposes `spawn`, `get`, `count`,
  `insert`, `remove`, `despawn`, `resource`, `run(system, ticks:)` and
  `advance(dt)`. Systems run through the normal scheduler with the same access
  checks, so a system that works in a test cannot rely on access it would not
  have in the game.
- Time is a manual clock. `run(..., ticks:)` and `advance(dt)` are the only
  things that advance it; wall-clock time never leaks into a test.
- Structural changes follow ADR-0004. Deferred commands apply at the end of
  each tick, and a test that needs an immediate result calls `world.flush()`.
- A test that never creates a `TestWorld` is a pure-function test and pays
  nothing for one.

Script globals live in the VM, not in the world, so tests must not mutate
module-level state. The runner enforces this rather than trusting authors: it
snapshots module globals before a test and fails the test if they differ
afterwards. If this check proves too costly or too noisy, the fallback is a VM
per module generation, not per test.

### Assertions record failures

`expect(cond)`, `expectEqual(a, b)`, `expectNear(a, b, tolerance)`,
`expectNil(x)` and `fail(message)` record a diagnostic and let the test continue
to its end. A failure is reported as `path:line:column: message`, using the
call-site location, in the format ADR-0001 uses for annotation diagnostics.
`require(cond)` records and stops the test, for cases where later lines would
only produce noise.

A runtime error inside a test, such as a failed VM call, fails that test and is
isolated from the others (ADR-0007). It never stops the runner.

### Tests never ship

The build generator drops `@test` functions, the `Tests/` root, and any
declaration reachable only from them. The production build verifies that no
remaining declaration references a test symbol (`TestWorld`, `expect*`,
anything from `Tests/`); a violation is a build error naming both locations.
The embedded source map, import graph and hot-reload generations (ADR-0007)
therefore contain no test code in a normal run.

In a test configuration, editing an inline test reloads its module like any
other edit.

### Runner and integration

`AdaScriptTestRunner` in `AdaScripting` compiles the module, collects tests,
runs each one and returns structured results: name, source location, outcome,
duration and diagnostics. It supports name filtering and a per-test timeout,
using the cooperative suspension rules from ADR-0015.

Entry points, all on the same runner:

1. **`swift test`:** one Swift Testing `@Test(arguments:)` runs the tests of
   every fixture project, so CI on macOS and Windows needs no new step.
2. **CLI:** a command that exits non-zero on failure and can emit JUnit or JSON.
3. **Editor:** a results panel and a run button beside each `@test`. Planned
   after ADR-0023's panel infrastructure is available.

### Compiler diagnostics use `#unittest`

Gravity's `#unittest { name; error; result }` stays available for tests of the
compiler and language service themselves, where the expected output is a syntax
or semantic error at a given row and column. It is not a gameplay-testing
mechanism, and the documentation says so.

## Consequences

- Authors write tests beside the code they cover and can test private helpers
  without widening visibility.
- Isolation is cheap: a `World` per test costs far less than a VM, and shared
  compiled code keeps the whole suite fast.
- The cost is a rule authors must follow, no module-level mutable state in
  tests, which the runner checks and reports.
- The production pipeline gains one more stripping pass and one more
  verification step. Both need tests of their own, in particular that stripped
  builds are byte-identical whether or not a test exists.
- `TestWorld` is a second, test-only world API. It must stay a thin layer over
  the same scheduler and access checks, or tests will pass for code that fails
  in the game.

## Rejected alternatives

- **A separate directory only.** Forces helpers to be public and separates the
  test from the code it explains.
- **A fresh VM per test.** The strongest isolation, but compiles or clones the
  module for every test and makes large suites slow. The globals check covers
  the leak that motivated it.
- **Extending `#unittest` for gameplay tests.** It checks one `main()` result
  per file and has no notion of worlds, systems or multiple tests per file.
- **A GUT-style class hierarchy** (`extends TestCase`). Ada Script annotations
  already carry intent, and a base class would add a new object model for no
  gain.
- **Raising on the first failed assertion.** Hides later independent failures;
  `require` covers the cases where stopping is right.

## Open questions

- Whether `TestWorld` may install arbitrary Swift plugins or only a fixed list,
  which affects how reproducible a test is across machines.
- Whether `@test` accepts parameters (`@test(cases: ...)`) in a later ADR.
- How the globals snapshot treats lazily initialized module state.
