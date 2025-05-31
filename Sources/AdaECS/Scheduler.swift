import Foundation

/// Represents a scheduler stage in the ECS update loop.
public struct Scheduler: Hashable, Equatable, RawRepresentable, CustomStringConvertible, Sendable {
    public let rawValue: String
    public var description: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // Default schedulers
    public static let fixedUpdate = Scheduler(rawValue: "fixedUpdate")
    public static let preUpdate = Scheduler(rawValue: "preUpdate")
    public static let update = Scheduler(rawValue: "update")
    public static let postUpdate = Scheduler(rawValue: "postUpdate")
}

public extension Scheduler {
    static var `default`: [Scheduler] {
        return [
            .preUpdate,
            .update,
            .fixedUpdate,
            .postUpdate
        ]
    }
}

/// Internal structure to manage schedulers and their order.
public final class Schedulers {
    private(set) var schedulerLabels: [Scheduler]
    private var schedulers: [Scheduler: SchedulerExecutor]

    public init(_ schedulers: [Scheduler]) {
        self.schedulerLabels = schedulers
        self.schedulers = Dictionary(
            uniqueKeysWithValues: schedulerLabels.map { ($0, SchedulerExecutor()) }
        )
    }

    public func setSchedulers(_ schedulers: [Scheduler]) {
        self.schedulerLabels = schedulers
        self.schedulers = Dictionary(
            uniqueKeysWithValues: schedulerLabels.enumerated().map { ($1, SchedulerExecutor()) }
        )
    }

    public func append(_ scheduler: Scheduler) {
        schedulerLabels.append(scheduler)
        schedulers[scheduler] = SchedulerExecutor()
    }

    public func insert(_ scheduler: Scheduler, after: Scheduler) {
        if schedulers[scheduler] != nil {
            fatalError("Already exists")
        }

        if let idx = schedulerLabels.firstIndex(of: after) {
            schedulerLabels.insert(scheduler, at: idx + 1)
        } else {
            schedulerLabels.append(scheduler)
        }
    }

    public func contains(_ scheduler: Scheduler) -> Bool {
        self.schedulers[scheduler] != nil
    }

    public func insert(_ scheduler: Scheduler, before: Scheduler) {
        if schedulers[scheduler] != nil {
            fatalError("Already exists")
        }

        if let idx = schedulerLabels.firstIndex(of: before) {
            schedulerLabels.insert(scheduler, at: idx)
        } else {
            schedulerLabels.append(scheduler)
        }
    }

    public func getScheduler(_ scheduler: Scheduler) -> SchedulerExecutor? {
        self.schedulers[scheduler]
    }
}

public struct SchedulerExecutor: Sendable {
    public let systemGraph: SystemsGraph = SystemsGraph()
    let runner: SystemsGraphExecutor = SystemsGraphExecutor()

    public init() {}
}
