//
//  MultiThreadedSystemsGraphExecutorTests.swift
//  AdaEngine
//

import AdaECS
import Foundation
import Testing

@Suite("MultiThreaded systems graph executor")
struct MultiThreadedSystemsGraphExecutorTests {

    @Test("read-only systems are compatible with each other")
    func readOnlySystemsAreCompatible() {
        var lhs = SystemAccessSet()
        lhs.addResourceRead(MultiThreadedReadResource.self)

        var rhs = SystemAccessSet()
        rhs.addResourceRead(MultiThreadedReadResource.self)

        #expect(lhs.isCompatible(with: rhs))
        #expect(rhs.isCompatible(with: lhs))
    }

    @Test("writes conflict with reads and writes for the same resource")
    func writesConflictWithReadsAndWrites() {
        var writer = SystemAccessSet()
        writer.addResourceWrite(MultiThreadedReadResource.self)

        var reader = SystemAccessSet()
        reader.addResourceRead(MultiThreadedReadResource.self)

        var secondWriter = SystemAccessSet()
        secondWriter.addResourceWrite(MultiThreadedReadResource.self)

        #expect(!writer.isCompatible(with: reader))
        #expect(!reader.isCompatible(with: writer))
        #expect(!writer.isCompatible(with: secondWriter))
    }

    @Test("component Ref access conflicts with component read access")
    func mutableComponentAccessConflictsWithComponentReadAccess() {
        let readAccess = Query<MultiThreadedPosition>.access
        let writeAccess = Query<Ref<MultiThreadedPosition>>.access

        #expect(!readAccess.isCompatible(with: writeAccess))
        #expect(!writeAccess.isCompatible(with: readAccess))
    }

    @Test("commands are deferred until the executor reaches an apply point")
    func commandsAreDeferredUntilApplyPoint() async throws {
        let world = World()
        world.addScheduler(Scheduler(name: .multiThreadedTest, graphExecutor: MultiThreadedSystemsGraphExecutor()))
        world.insertResource(CommandVisibilityLog(values: []))
        world.addSystem(DeferredSpawnSystem.self, on: .multiThreadedTest)
        world.addSystem(ReadBeforeCommandsAreAppliedSystem.self, on: .multiThreadedTest)
        world.addSystem(ReadAfterCommandsAreAppliedSystem.self, on: .multiThreadedTest)

        await world.runScheduler(.multiThreadedTest)

        let log = try #require(world.getResource(CommandVisibilityLog.self))
        #expect(log.values == [0, 1])
    }

    @Test("conflicting systems keep the single-threaded executor order")
    func conflictingSystemsKeepSingleThreadedOrder() async throws {
        let singleThreadedLog = try await runOrderTest(with: SingleThreadedSystemsGraphExecutor())
        let multiThreadedLog = try await runOrderTest(with: MultiThreadedSystemsGraphExecutor())

        #expect(multiThreadedLog == singleThreadedLog)
    }

    private func runOrderTest(with executor: any SystemsGraphExecutor) async throws -> [String] {
        let world = World()
        world.addScheduler(Scheduler(name: .multiThreadedOrderTest, graphExecutor: executor))
        world.insertResource(MultiThreadedOrderLog(values: []))
        world.addSystem(FirstConflictingOrderSystem.self, on: .multiThreadedOrderTest)
        world.addSystem(SecondConflictingOrderSystem.self, on: .multiThreadedOrderTest)

        await world.runScheduler(.multiThreadedOrderTest)

        return try #require(world.getResource(MultiThreadedOrderLog.self)).values
    }
}

struct MultiThreadedReadResource: Resource {
    var value: Int = 0
}

struct MultiThreadedPosition: Component {
    var x: Int = 0
}

struct CommandVisibilityLog: Resource, Equatable {
    var values: [Int]
}

struct MultiThreadedOrderLog: Resource, Equatable {
    var values: [String]
}

@PlainSystem
struct DeferredSpawnSystem {
    @Commands
    private var commands

    init(world: World) {}

    func update(context: UpdateContext) {
        commands.spawn {
            MultiThreadedPosition(x: 1)
        }
    }
}

@PlainSystem
struct ReadBeforeCommandsAreAppliedSystem {
    @Query<MultiThreadedPosition>
    private var query

    @ResMut
    private var log: CommandVisibilityLog

    init(world: World) {}

    func update(context: UpdateContext) {
        log.values.append(query.count)
    }
}

@PlainSystem(dependencies: [
    .after(ReadBeforeCommandsAreAppliedSystem.self)
])
struct ReadAfterCommandsAreAppliedSystem {
    @Query<MultiThreadedPosition>
    private var query

    @ResMut
    private var log: CommandVisibilityLog

    init(world: World) {}

    func update(context: UpdateContext) {
        log.values.append(query.count)
    }
}

@PlainSystem
struct FirstConflictingOrderSystem {
    @ResMut
    private var log: MultiThreadedOrderLog

    init(world: World) {}

    func update(context: UpdateContext) {
        log.values.append("first")
    }
}

@PlainSystem
struct SecondConflictingOrderSystem {
    @ResMut
    private var log: MultiThreadedOrderLog

    init(world: World) {}

    func update(context: UpdateContext) {
        log.values.append("second")
    }
}

private extension SchedulerName {
    static let multiThreadedTest: SchedulerName = "MultiThreadedTest"
    static let multiThreadedOrderTest: SchedulerName = "MultiThreadedOrderTest"
}
