//
//  RenderScene.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/21/23.
//

import AdaECS
import AdaUtils
import Logging

/// RenderWorld that store entities for rendering. Each update tick entities removed from RenderWorld.
@RenderGraphActor
public final class RenderWorld: Sendable {
    let renderGraphExecutor = RenderGraphExecutor()
    public let renderGraph: RenderGraph = RenderGraph(label: "RenderWorld")

    public let world: World = World()

    @MainActor
    @_spi(Internal)
    public init() {}

    /// Add a new system to the scene.
    @discardableResult
    public func addSystem<T: RenderSystem>(_ systemType: T.Type) -> Self {
        world.addSystem(systemType)
        return self
    }
    
    /// Add a new scene plugin to the scene.
    @discardableResult
    public func addPlugin<T: RenderWorldPlugin>(_ plugin: T) async -> Self {
        await plugin.setup(in: self)
        return self
    }
    
    /// Add a new entity to render world.
    @discardableResult
    public func addEntity(_ entity: Entity) -> Self {
        self.world.addEntity(entity)
        return self
    }

    public func update(_ deltaTime: AdaUtils.TimeInterval) async throws {
        await self.world.update(deltaTime)
        try await self.renderGraphExecutor.execute(self.renderGraph, in: world)
        self.world.clear()
    }
}
