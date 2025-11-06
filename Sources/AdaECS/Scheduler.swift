import AdaUtils

/// Represents a scheduler stage in the ECS update loop.
public struct SchedulerName: Hashable, Equatable, RawRepresentable, CustomStringConvertible, Sendable {
    /// The raw value of the scheduler name.
    public let rawValue: String

    /// The description of the scheduler name.
    public var description: String { rawValue }

    /// Initialize a new scheduler name.
    /// - Parameter rawValue: The raw value of the scheduler name.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension SchedulerName: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

/// Default schedulers.
public extension SchedulerName {
    /// The pre-update scheduler.
    static let preUpdate = SchedulerName(rawValue: "preUpdate")

    /// The update scheduler.
    static let update = SchedulerName(rawValue: "update")

    /// The post-update scheduler.
    static let postUpdate = SchedulerName(rawValue: "postUpdate")

    /// The default scheduler order.
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

    /// Initialize a new schedulers.
    /// - Parameter schedulers: The schedulers to initialize.
    public init(_ schedulers: [SchedulerName] = []) {
        self.schedulerLabels = schedulers
        self.schedulers = Dictionary(
            uniqueKeysWithValues: schedulerLabels.map { ($0, Scheduler(name: $0)) }
        )
    }

    /// Set the schedulers.
    /// - Parameter schedulers: The schedulers to set.
    public func setSchedulers(_ schedulers: [SchedulerName]) {
        self.schedulerLabels = schedulers
        self.schedulers = Dictionary(
            uniqueKeysWithValues: schedulerLabels.enumerated().map { ($1, Scheduler(name: $1)) }
        )
    }

    /// Append a scheduler.
    /// - Parameter scheduler: The scheduler to append.
    public func append(_ scheduler: Scheduler) {
        schedulerLabels.append(scheduler.name)
        schedulers[scheduler.name] = scheduler
    }

    /// Insert a scheduler after a specific scheduler.
    /// - Parameter scheduler: The scheduler to insert.
    /// - Parameter after: The scheduler to insert after.
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

    /// Check if the schedulers contains a specific scheduler.
    /// - Parameter scheduler: The scheduler to check.
    /// - Returns: True if the schedulers contains the scheduler, otherwise false.
    public func contains(_ scheduler: SchedulerName) -> Bool {
        self.schedulers[scheduler] != nil
    }

    /// Insert a scheduler before a specific scheduler.
    /// - Parameter scheduler: The scheduler to insert.
    /// - Parameter before: The scheduler to insert before.
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

    /// Get a scheduler by its name.
    /// - Parameter scheduler: The name of the scheduler.
    /// - Returns: The scheduler if it exists, otherwise nil.
    public func getScheduler(_ scheduler: SchedulerName) -> Scheduler? {
        self.schedulers[scheduler]
    }

    /// Add system to scheduler. If scheduler not exists, than we create it.
    public func addSystem<T: System>(_ system: T, for schedulerName: SchedulerName) {
        if schedulers[schedulerName] == nil {
            schedulerLabels.append(schedulerName)
        }
        let scheduler = self.schedulers[schedulerName] ?? Scheduler(name: schedulerName)
        scheduler
            .systemGraph
            .addSystem(system)
        self.schedulers[schedulerName] = scheduler
    }
}

/// A resource that contains the delta time.
public struct DeltaTime: Resource {
    /// The delta time.
    public let deltaTime: AdaUtils.TimeInterval

    /// Initialize a new delta time.
    /// - Parameter deltaTime: The delta time.
    public init(deltaTime: AdaUtils.TimeInterval) {
        self.deltaTime = deltaTime
    }
}

/// A resource that contains the delta time.
public struct FixedTime: Resource {
    /// The delta time.
    public let deltaTime: AdaUtils.TimeInterval

    /// Initialize a new delta time.
    /// - Parameter deltaTime: The delta time.
    public init(deltaTime: AdaUtils.TimeInterval) {
        self.deltaTime = deltaTime
    }
}

/// A resource that contains the order of the default scheduler.
public struct DefaultSchedulerOrder: Resource {
    public let order: [SchedulerName]

    public init(order: [SchedulerName] = [.preUpdate, .update, .postUpdate]) {
        self.order = order
    }
}

/// A system that runs the default scheduler.
@PlainSystem
public struct DefaultSchedulerRunner: Sendable {

    @ResQuery
    private var order: DefaultSchedulerOrder?

    @LocalIsolated
    private var lastUpdate: LongTimeInterval = 0

    public init(world: World) { }

    public func update(context: inout UpdateContext) async {
        let world = context.world
        let order = order?.order ?? []
        for scheduler in order {
            await world.runScheduler(scheduler)
        }
    }
}

/// A scheduler that runs systems in a specific order.
public final class Scheduler: @unchecked Sendable {
    public typealias RunnerBlock = (any System) -> Void

    /// The name of the scheduler.
    public let name: SchedulerName

    /// The system graph of the scheduler.
    public var systemGraph: SystemsGraph = SystemsGraph()

    /// The graph executor of the scheduler.
    var graphExecutor: any SystemsGraphExecutor = SingleThreadedSystemsGraphExecutor()

    /// The last update time of the scheduler.
    @LocalIsolated private var lastUpdate: LongTimeInterval = 0

    /// Initialize a new scheduler.
    /// - Parameter name: The name of the scheduler.
    public init(name: SchedulerName) {
        self.name = name
    }

    /// Run the scheduler.
    /// - Parameter world: The world to run the scheduler on.
    public func run(world: World) async {
        let now = Time.absolute
        let deltaTime = TimeInterval(max(0, now - self.lastUpdate))
        self.lastUpdate = now

        if self.systemGraph.isChanged {
            self.systemGraph.linkSystems()
            self.graphExecutor.initialize(self.systemGraph)
        }

        let name = self.name
        world.insertResource(DeltaTime(deltaTime: deltaTime))

        await graphExecutor.execute(systemGraph, world: world, scheduler: name)
    }
}
