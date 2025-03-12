//
//  RenderScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/21/23.
//

import Logging

/// RenderWorld that store entities for rendering. Each update tick entities removed from RenderWorld.
@MainActor
public final class RenderWorld {
    let renderGraphExecutor = RenderGraphExecutor()
    @RenderGraphActor public let renderGraph: RenderGraph = RenderGraph(label: "RenderWorld")
    private let scene = Scene(name: "RenderWorld")

    public var world: World {
        return self.scene.world
    }
    
    /// Add a new system to the scene.
    public func addSystem<T: RenderSystem>(_ systemType: T.Type) {
        scene.addSystem(systemType)
    }
    
    /// Add a new scene plugin to the scene.
    public func addPlugin<T: RenderWorldPlugin>(_ plugin: T) async {
        await plugin.setup(in: self)
    }
    
    /// Add a new entity to render world.
    public func addEntity(_ entity: Entity) {
        self.scene.addEntity(entity)
    }

    func update(_ deltaTime: TimeInterval) async throws {
        self.scene.update(deltaTime)
        try await self.renderGraphExecutor.execute(self.renderGraph, in: world)

        self.scene.world.clear()
    }
}
