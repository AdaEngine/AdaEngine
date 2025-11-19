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
        let mainScheduler = Scheduler(name: .main)
        app.updateScheduler = .main

        app.main.addScheduler(mainScheduler)
        app.main.addSchedulers(
            .fixed,
            .postUpdate
        )

        app
            .addSystem(DefaultSchedulerRunner.self, on: .main)
            .addSystem(FixedTimeSchedulerSystem.self, on: .fixed)
            .addSystem(PostUpdateSchedulerRunner.self, on: .postUpdate)
        app.insertResource(DefaultSchedulerOrder())
        app.addSystem(GameLoopBeganSystem.self, on: .preUpdate)
    }
}

extension SchedulerName {
    static let main: SchedulerName = "Main"
    static let fixed: SchedulerName = "FixedMain"
}

// FIXME: Hack to works with AnimatedTexture
@System
@inline(__always)
func GameLoopBegan(
    _ deltaTime: Res<DeltaTime?>
) {
    guard let deltaTime = deltaTime.wrappedValue else { return }
    EventManager.default.send(EngineEvents.MainLoopBegan(deltaTime: deltaTime.deltaTime))
}

/// The system that runs the fixed time scheduler.
@PlainSystem
public struct FixedTimeSchedulerSystem {

    @Local
    private var fixedTimestep: FixedTimestep

    let order: [SchedulerName] = [
        .fixedPreUpdate,
        .fixedUpdate,
        .fixedPostUpdate
    ]

    public init(world: World) {
        self.fixedTimestep = FixedTimestep(stepsPerSecond: 60)
    }

    @Res<DeltaTime?>
    private var deltaTime

    public func update(context: inout UpdateContext) async {
        let deltaTime = deltaTime?.deltaTime ?? 0
        let result = self.fixedTimestep.advance(with: deltaTime)

        if result.isFixedTick {
            let step = self.fixedTimestep.step
            let world = context.world
            world.insertResource(FixedTime(deltaTime: step))
//            context.taskGroup.addTask(priority: .high) { [order] in
            for scheduler in order {
                await world.runScheduler(scheduler)
            }
        }
    }
}

/// The system that runs the post update scheduler.
@PlainSystem
public struct PostUpdateSchedulerRunner: Sendable {
    
    public init(world: World) { }

    public func update(context: inout UpdateContext) async {
        let world = context.world
//        await world.runScheduler(.postUpdate)
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
