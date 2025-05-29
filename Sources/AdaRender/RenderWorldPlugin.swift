//
//  WorldPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/11/22.
//

import AdaApp
import AdaECS

public struct RenderWorld: Label {}

public struct RenderWorldPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        guard let renderWorld = app.getSubworldBuilder(by: RenderWorld.self) else {
            return
        }

        renderWorld
            .addSystem(RenderWorldSystem.self)
    }
}

@System
struct RenderWorldSystem {
    private let renderGraphExecutor = RenderGraphExecutor()

    init(world: World) { }

    @ResourceQuery
    private var renderGraph: RenderGraph!

    func update(context: UpdateContext) {
        context.scheduler.addTask {
            do {
                try await self.renderGraphExecutor.execute(renderGraph, in: context.world)
            } catch {
                print(error)
            }
        }
    }
}

///// RenderWorld that store entities for rendering. Each update tick entities removed from RenderWorld.
//@RenderGraphActor
//public final class RenderWorld: Sendable {
//    let renderGraphExecutor = RenderGraphExecutor()
//    public
//
//    public let world: World = World()
//
//    @MainActor
//    @_spi(Internal)
//    public init() {}
//
//    public func update(_ deltaTime: AdaUtils.TimeInterval) async throws {
//        await self.world.update(deltaTime)
//        try await self.renderGraphExecutor.execute(self.renderGraph, in: world)
//        self.world.clear()
//    }
//}
