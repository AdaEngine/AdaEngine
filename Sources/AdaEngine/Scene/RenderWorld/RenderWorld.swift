//
//  RenderScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/21/23.
//

import AdaECS
import Logging

/// RenderWorld that store entities for rendering. Each update tick entities removed from RenderWorld.
public final class RenderWorld: Sendable {
    let renderGraphExecutor = RenderGraphExecutor()
    @RenderGraphActor public let renderGraph: RenderGraph = RenderGraph(label: "RenderWorld")

    public let world: World = World()
    
    /// Add a new system to the scene.
    public func addSystem<T: RenderSystem>(_ systemType: T.Type) {
        world.addSystem(systemType)
    }
    
    /// Add a new scene plugin to the scene.
    public func addPlugin<T: RenderWorldPlugin>(_ plugin: T) async {
        await plugin.setup(in: self)
    }
    
    /// Add a new entity to render world.
    public func addEntity(_ entity: Entity) {
        self.world.addEntity(entity)
    }

    func update(_ deltaTime: TimeInterval) async throws {
        await self.world.update(deltaTime)
        try await self.renderGraphExecutor.execute(self.renderGraph, in: world)
        self.world.clear()
    }
}
