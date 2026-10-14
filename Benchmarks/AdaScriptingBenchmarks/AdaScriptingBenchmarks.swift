@_spi(Scripting) import AdaApp
@_spi(Scripting) import AdaECS
import AdaScripting
import Benchmark
import Foundation

// MARK: - Components

@Component
private struct Position {
    var x: Float
    var y: Float
}

@Component
private struct Velocity {
    var x: Float
    var y: Float
}

// MARK: - Constants

private enum BenchConstants {
    static let smoke = ProcessInfo.processInfo.environment["ADAENGINE_BENCHMARK_SMOKE"] == "1"
    static let entities = smoke ? 1_000 : 100_000
}

// MARK: - Fixtures

private func makeWorld(entityCount: Int) -> World {
    let world = World(name: "ScriptingBenchmark")
    for index in 0..<entityCount {
        world.spawn {
            Position(x: Float(index), y: Float(index))
            Velocity(x: 1, y: -1)
        }
    }
    return world
}

@MainActor
private func registerComponents() {
    RuntimeTypeRegistry.registerComponent(Position.self, names: ["Position"], makeDefault: { Position(x: 0, y: 0) })
    RuntimeTypeRegistry.registerComponent(Velocity.self, names: ["Velocity"], makeDefault: { Velocity(x: 0, y: 0) })
    ComponentReflectionRegistry.register(Position.componentDescriptor)
    ComponentReflectionRegistry.register(Velocity.componentDescriptor)
}

private struct GravityFixture {
    let world: World
    let plugin: AdaScriptPlugin
}

/// Installs one script system over the benchmark world. `body` is the loop body run for every row.
@MainActor
private func makeGravityFixture(body: String, access: String = "") throws -> GravityFixture {
    registerComponents()
    let plugin = try AdaScriptPlugin(
        source: """
        @system(id: "bench.system")
        \(access)
        class BenchSystem {
            @query(Position, Velocity)
            var rows;

            func update(context) {
                for (var row in rows) {
                    \(body)
                }
            }
        }
        """,
        name: "ScriptingBenchmark"
    )
    let world = makeWorld(entityCount: BenchConstants.entities)
    plugin.setup(in: AppWorlds(main: world))
    return GravityFixture(world: world, plugin: plugin)
}

private func makeTypedFixture() -> (World, Query<Ref<Position>, Velocity>) {
    let world = makeWorld(entityCount: BenchConstants.entities)
    let query = Query<Ref<Position>, Velocity>()
    query.update(from: world)
    precondition(query.count == BenchConstants.entities, "Benchmark query must visit every fixture entity")
    return (world, query)
}

private func makeNativeCursorFixture() throws -> (World, DynamicQuery, [ReflectedComponentField], [ReflectedComponentField]) {
    let world = makeWorld(entityCount: BenchConstants.entities)
    var access = SystemAccessSet()
    access.addComponentWrite(Position.self)
    access.addComponentRead(Velocity.self)
    let query = DynamicQuery(
        where: .has(Position.self) && .has(Velocity.self),
        components: [Position.identifier, Velocity.identifier],
        access: access
    )
    query.update(from: world)
    return (world, query, Position.componentDescriptor.fields, Velocity.componentDescriptor.fields)
}

// MARK: - Benchmarks

// Compares the same `position += velocity` update through three layers of the scripting stack. The typed query
// is AdaECS's own fast path; the native cursor is what the bridge drives per row; Gravity adds the VM and the
// bridge objects. QueryOnly isolates iteration from field access.
let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: [.wallClock, .cpuTotal, .mallocCountTotal],
        warmupIterations: 1,
        scalingFactor: .one,
        maxDuration: BenchConstants.smoke ? .milliseconds(200) : .seconds(5),
        maxIterations: BenchConstants.smoke ? 3 : 20
    )

    Benchmark(
        "AdaScripting.SimpleIter.Typed",
        closure: { benchmark, state in
            let (world, query) = state
            for _ in benchmark.scaledIterations {
                query.forEach { position, velocity in
                    position.x += velocity.x
                    position.y += velocity.y
                }
            }
            benchmark.stopMeasurement()
            blackHole(world)
        },
        setup: {
            makeTypedFixture()
        }
    )

    Benchmark(
        "AdaScripting.SimpleIter.NativeCursor",
        closure: { benchmark, state in
            let (world, query, positionFields, velocityFields) = state
            let cursor = query.wrappedValue.makeCursor()
            for _ in benchmark.scaledIterations {
                cursor.reset()
                while cursor.advance() {
                    for (position, velocity) in zip(positionFields, velocityFields) {
                        let delta = cursor.read(componentAt: 1, field: velocity)?.doubleValue ?? 0
                        let value = cursor.read(componentAt: 0, field: position)?.doubleValue ?? 0
                        cursor.write(componentAt: 0, field: position, value: .double(value + delta))
                    }
                }
            }
            benchmark.stopMeasurement()
            blackHole(world)
        },
        setup: {
            try makeNativeCursorFixture()
        }
    )

    Benchmark(
        "AdaScripting.SimpleIter.Gravity",
        closure: { benchmark, fixture in
            for _ in benchmark.scaledIterations {
                await fixture.world.runScheduler(.update)
            }
            benchmark.stopMeasurement()
            precondition(fixture.plugin.diagnostics.isEmpty, "Gravity benchmark system reported diagnostics")
        },
        setup: {
            try await MainActor.run {
                try makeGravityFixture(
                    body: "row.position.x += row.velocity.x; row.position.y += row.velocity.y;"
                )
            }
        }
    )

    Benchmark(
        "AdaScripting.QueryOnly.Gravity",
        closure: { benchmark, fixture in
            for _ in benchmark.scaledIterations {
                await fixture.world.runScheduler(.update)
            }
            benchmark.stopMeasurement()
            precondition(fixture.plugin.diagnostics.isEmpty, "Gravity benchmark system reported diagnostics")
        },
        setup: {
            try await MainActor.run {
                try makeGravityFixture(body: "var id = row.id;", access: "@access(read: [Position, Velocity])")
            }
        }
    )
}
