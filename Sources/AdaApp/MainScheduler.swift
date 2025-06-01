//
//  MainScheduler.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 01.06.2025.
//

import AdaECS
import AdaUtils

struct MainSchedulerPlugin: Plugin {
    func setup(in app: AppWorlds) {
        let mainScheduler = Scheduler(name: .update)
        let fixedScheduler = Scheduler(name: .fixedUpdate, system: FixedTimeSchedulerSystem.self)
        app.setSchedulers([
            mainScheduler,
            fixedScheduler
        ])
        app.mainWorld.insertResource(DefaultSchedulerOrder())
        app.mainWorld.addSchedulers(
            .fixedPreUpdate,
            .fixedUpdate,
            .fixedPostUpdate,
        )
    }
}

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

    public func update(context: UpdateContext) {
        let result = self.fixedTimestep.advance(with: context.deltaTime)

        if result.isFixedTick {
            let step = self.fixedTimestep.step
            for scheduler in order {
                context.taskGroup.addTask {
                    await context.world.runScheduler(scheduler, deltaTime: step)
                }
            }
        }
    }
}

extension SchedulerName {
    public static let fixedPreUpdate = SchedulerName(rawValue: "fixedPreUpdate")
    public static let fixedUpdate = SchedulerName(rawValue: "fixedUpdate")
    public static let fixedPostUpdate = SchedulerName(rawValue: "fixedPostUpdate")
}
