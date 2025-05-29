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

    public func update(_ deltaTime: AdaUtils.TimeInterval) async throws {
        await self.world.update(deltaTime)
        try await self.renderGraphExecutor.execute(self.renderGraph, in: world)
        self.world.clear()
    }
}
