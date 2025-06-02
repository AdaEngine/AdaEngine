//
//  MainScheduler.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.06.2025.
//

import AdaECS
import AdaUtils

/// The plugin that sets up the main scheduler.
struct MainSchedulerPlugin: Plugin {
    /// Setup the main scheduler.
    /// - Parameter app: The app to setup the main scheduler for.
    func setup(in app: AppWorlds) {
        let mainScheduler = Scheduler(name: .update)
        let fixedScheduler = Scheduler(name: .fixedUpdate, system: FixedTimeSchedulerSystem.self)
        let postUpdateScheduler = Scheduler(name: .postUpdate, system: PostUpdateSchedulerRunner.self)
        app.setSchedulers([
            mainScheduler,
            fixedScheduler,
            postUpdateScheduler
        ])
        app.mainWorld.insertResource(DefaultSchedulerOrder())
        app.mainWorld.addSchedulers(
            .fixedPreUpdate,
            .fixedUpdate,
            .fixedPostUpdate,
        )
    }
}

/// The system that runs the fixed time scheduler.
@System
public struct FixedTimeSchedulerSystem {

    @LocalIsolated
    private var fixedTimestep: FixedTimestep

    let order: [SchedulerName] = [
        .fixedPreUpdate,
        .fixedUpdate,
        .fixedPostUpdate
    ]

    public init(world: World) {
        self.fixedTimestep = FixedTimestep(stepsPerSecond: 60)
    }

    public func update(context: inout UpdateContext) {
        let result = self.fixedTimestep.advance(with: context.deltaTime)

        if result.isFixedTick {
            let step = self.fixedTimestep.step
            let world = context.world
            context.taskGroup.addTask { [order] in
                for scheduler in order {
                    await world.runScheduler(scheduler, deltaTime: step)
                }
            }
        }
    }
}

/// The system that runs the post update scheduler.
@System
public struct PostUpdateSchedulerRunner: Sendable {

    @ResQuery
    private var order: DefaultSchedulerOrder?

    @LocalIsolated
    private var lastUpdate: LongTimeInterval = 0

    public init(world: World) { }

    public func update(context: inout UpdateContext) {
        let world = context.world
        let deltaTime = context.deltaTime
        context.taskGroup.addTask {
            await world.runScheduler(.postUpdate, deltaTime: deltaTime)
        }
    }
}

extension SchedulerName {
    /// The fixed pre-update scheduler.
    public static let fixedPreUpdate = SchedulerName(rawValue: "fixedPreUpdate")

    /// The fixed update scheduler.
    public static let fixedUpdate = SchedulerName(rawValue: "fixedUpdate")

    /// The fixed post-update scheduler.
    public static let fixedPostUpdate = SchedulerName(rawValue: "fixedPostUpdate")
}
