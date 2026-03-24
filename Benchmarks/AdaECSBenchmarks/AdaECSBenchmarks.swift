import AdaECS
import Benchmark

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

@Component
private struct CompA {
    var value: Float
}

@Component
private struct CompB {
    var value: Float
}

@Component
private struct CompC {
    var value: Float
}

@Component
private struct FragData {
    var value: Float
}

@Component
private struct Matrix4x4 {
    var m00: Float, m01: Float, m02: Float, m03: Float
    var m10: Float, m11: Float, m12: Float, m13: Float
    var m20: Float, m21: Float, m22: Float, m23: Float
    var m30: Float, m31: Float, m32: Float, m33: Float
}

// MARK: - Constants

private enum BenchConstants {
    static let spawnEntities = 100_000
    static let simpleIterEntities = 100_000
    static let fragmentedEntitiesPerType = 33_334
    static let heavyComputeEntities = 1_000
    static let heavyComputeIterations = 100
    static let addRemoveEntities = 100_000
}

// MARK: - Setup Helpers

private func makeSimpleIterWorld(entityCount: Int) -> (World, Query<Ref<Position>, Velocity>) {
    let world = World()
    for i in 0..<entityCount {
        world.spawn {
            Position(x: Float(i), y: Float(i))
            Velocity(x: 1, y: -1)
        }
    }

    let query = Query<Ref<Position>, Velocity>()
    query.update(from: world)

    return (world, query)
}

private func makeFragmentedIterWorld(entitiesPerType: Int) -> (World, Query<Ref<FragData>>) {
    let world = World()

    for i in 0..<entitiesPerType {
        world.spawn {
            CompA(value: Float(i))
            FragData(value: Float(i))
        }
    }
    for i in 0..<entitiesPerType {
        world.spawn {
            CompB(value: Float(i))
            FragData(value: Float(i))
        }
    }
    for i in 0..<entitiesPerType {
        world.spawn {
            CompC(value: Float(i))
            FragData(value: Float(i))
        }
    }

    let query = Query<Ref<FragData>>()
    query.update(from: world)

    return (world, query)
}

private func makeHeavyComputeWorld(entityCount: Int) -> (World, Query<Ref<Matrix4x4>>) {
    let world = World()
    for _ in 0..<entityCount {
        world.spawn {
            Matrix4x4(
                m00: 1, m01: 0, m02: 0, m03: 0,
                m10: 0, m11: 1, m12: 0, m13: 0,
                m20: 0, m21: 0, m22: 1, m23: 0,
                m30: 0, m31: 0, m32: 0, m33: 1
            )
        }
    }

    let query = Query<Ref<Matrix4x4>>()
    query.update(from: world)

    return (world, query)
}

private func makeAddRemoveWorld(entityCount: Int) -> (World, [Entity.ID]) {
    let world = World()
    var ids: [Entity.ID] = []
    ids.reserveCapacity(entityCount)

    for i in 0..<entityCount {
        let entity = world.spawn {
            Position(x: Float(i), y: Float(i))
        }
        ids.append(entity.id)
    }

    return (world, ids)
}

// MARK: - Benchmarks

let benchmarks: @Sendable () -> Void = {
    Benchmark("AdaECS.Spawn") { benchmark in
        // #region agent log
        DebugBenchmarkLog.benchmarkPhase(name: "Spawn", phase: "start")
        // #endregion
        for _ in benchmark.scaledIterations {
            let world = World()
            for _ in 0..<BenchConstants.spawnEntities {
                world.spawn()
            }
            blackHole(world)
        }
        // #region agent log
        DebugBenchmarkLog.benchmarkPhase(name: "Spawn", phase: "end")
        // #endregion
    }

    Benchmark(
        "AdaECS.SimpleIter",
        closure: { benchmark, state in
            // #region agent log
            DebugBenchmarkLog.benchmarkPhase(name: "SimpleIter", phase: "start")
            // #endregion
            let (world, query) = state
            for _ in benchmark.scaledIterations {
                query.forEach { position, velocity in
                    position.x += velocity.x
                    position.y += velocity.y
                }
            }
            blackHole(world)
            // #region agent log
            DebugBenchmarkLog.benchmarkPhase(name: "SimpleIter", phase: "end")
            // #endregion
        },
        setup: {
            makeSimpleIterWorld(entityCount: BenchConstants.simpleIterEntities)
        }
    )

    Benchmark(
        "AdaECS.FragmentedIter",
        closure: { benchmark, state in
            // #region agent log
            DebugBenchmarkLog.benchmarkPhase(name: "FragmentedIter", phase: "start")
            // #endregion
            let (world, query) = state
            for _ in benchmark.scaledIterations {
                for data in query {
                    data.value *= 2.0
                }
            }
            blackHole(world)
            // #region agent log
            DebugBenchmarkLog.benchmarkPhase(name: "FragmentedIter", phase: "end")
            // #endregion
        },
        setup: {
            makeFragmentedIterWorld(entitiesPerType: BenchConstants.fragmentedEntitiesPerType)
        }
    )

    Benchmark(
        "AdaECS.HeavyCompute",
        closure: { benchmark, state in
            let (world, query) = state
            for _ in benchmark.scaledIterations {
                for transform in query {
                    for _ in 0..<BenchConstants.heavyComputeIterations {
                        transform.m00 += 1.0
                    }
                }
            }
            blackHole(world)
        },
        setup: {
            makeHeavyComputeWorld(entityCount: BenchConstants.heavyComputeEntities)
        }
    )

    Benchmark(
        "AdaECS.AddRemove",
        closure: { benchmark, state in
            // #region agent log
            DebugBenchmarkLog.benchmarkPhase(name: "AddRemove", phase: "start")
            // #endregion
            let (world, ids) = state
            for _ in benchmark.scaledIterations {
                for id in ids {
                    world.insert(Velocity(x: 1, y: -1), for: id)
                }
                for id in ids {
                    world.remove(Velocity.self, from: id)
                }
            }
            blackHole(world)
            // #region agent log
            DebugBenchmarkLog.benchmarkPhase(name: "AddRemove", phase: "end")
            // #endregion
        },
        setup: {
            makeAddRemoveWorld(entityCount: BenchConstants.addRemoveEntities)
        }
    )
}
