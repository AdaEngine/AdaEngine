import AdaUtils

/// Represents a scheduler stage in the ECS update loop.
public struct SchedulerName: Hashable, Equatable, RawRepresentable, CustomStringConvertible, Sendable {
    public let rawValue: String
    public var description: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension SchedulerName {
    // Default schedulers
    static let preUpdate = SchedulerName(rawValue: "preUpdate")
    static let update = SchedulerName(rawValue: "update")
    static let postUpdate = SchedulerName(rawValue: "postUpdate")

    static var `default`: [SchedulerName] {
        return [
            .preUpdate,
            .update,
            .postUpdate
        ]
    }
}

/// Internal structure to manage schedulers and their order.
public final class Schedulers: @unchecked Sendable {
    private(set) var schedulerLabels: [SchedulerName]
    private var schedulers: [SchedulerName: Scheduler]

    public init(_ schedulers: [SchedulerName]) {
        self.schedulerLabels = schedulers
        self.schedulers = Dictionary(
            uniqueKeysWithValues: schedulerLabels.map { ($0, Scheduler(name: $0)) }
        )
    }

    public func setSchedulers(_ schedulers: [SchedulerName]) {
        self.schedulerLabels = schedulers
        self.schedulers = Dictionary(
            uniqueKeysWithValues: schedulerLabels.enumerated().map { ($1, Scheduler(name: $1)) }
        )
    }

    public func append(_ scheduler: Scheduler) {
        schedulerLabels.append(scheduler.name)
        schedulers[scheduler.name] = scheduler
    }

    public func insert(_ scheduler: Scheduler, after: SchedulerName) {
        if schedulers[scheduler.name] != nil {
            fatalError("Already exists")
        }

        if let idx = schedulerLabels.firstIndex(of: after) {
            schedulerLabels.insert(scheduler.name, at: idx + 1)
        } else {
            schedulerLabels.append(scheduler.name)
        }
    }

    public func contains(_ scheduler: SchedulerName) -> Bool {
        self.schedulers[scheduler] != nil
    }

    public func insert(_ scheduler: Scheduler, before: SchedulerName) {
        if schedulers[scheduler.name] != nil {
            fatalError("Already exists")
        }

        if let idx = schedulerLabels.firstIndex(of: before) {
            schedulerLabels.insert(scheduler.name, at: idx)
        } else {
            schedulerLabels.append(scheduler.name)
        }
    }

    public func getScheduler(_ scheduler: SchedulerName) -> Scheduler? {
        self.schedulers[scheduler]
    }
}

public struct DefaultSchedulerOrder: Resource {
    public let order: [SchedulerName]

    public init(order: [SchedulerName] = [.preUpdate, .update, .postUpdate]) {
        self.order = order
    }
}

@System
public struct DefaultSchedulerRunner: Sendable {

    @ResourceQuery
    private var order: DefaultSchedulerOrder?

    @LocalIsolated
    private var lastUpdate: LongTimeInterval = 0

    public init(world: World) { }

    public func update(context: UpdateContext) {
        context.taskGroup.addTask {
            for scheduler in order?.order ?? [] {
                await context.world.runScheduler(scheduler, deltaTime: context.deltaTime)
            }
        }
    }
}

public final class Scheduler: @unchecked Sendable {
    public typealias RunnerBlock = (any System) -> Void

    public let name: SchedulerName
    public let systemGraph: SystemsGraph = SystemsGraph()
    let graphExecutor: SystemsGraphExecutor = SystemsGraphExecutor()
    let runnerSystemsBuilder: (World) -> any System
    var runnerSystem: (any System)?

    @LocalIsolated private var lastUpdate: LongTimeInterval = 0

    public init<T: System>(name: SchedulerName, system: T.Type) {
        self.name = name
        self.runnerSystemsBuilder = { T.init(world: $0) }
    }

    public init(name: SchedulerName) {
        self.name = name
        self.runnerSystemsBuilder = { DefaultSchedulerRunner.init(world: $0) }
    }

    @MainActor
    public func run(world: World) async {
        let now = Time.absolute
        let deltaTime = TimeInterval(max(0, now - self.lastUpdate))
        self.lastUpdate = now

        if self.runnerSystem == nil {
            self.runnerSystem = self.runnerSystemsBuilder(world)
        }

        if let runnerSystem = runnerSystem {
            await withTaskGroup(of: Void.self) { @MainActor group in
                let context = WorldUpdateContext(
                    world: world,
                    deltaTime: deltaTime,
                    scheduler: name,
                    taskGroup: group
                )
                runnerSystem.queries.queries.forEach { $0.update(from: world) }
                runnerSystem.update(context: context)
            }
        }
    }
}
