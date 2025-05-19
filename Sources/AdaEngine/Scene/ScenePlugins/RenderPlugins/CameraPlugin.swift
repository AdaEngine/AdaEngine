//
//  CameraPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

import AdaECS

struct CameraPlugin: WorldPlugin {
    func setup(in world: World) {
        world.addSystem(CameraSystem.self)
        world.addSystem(ExtractCameraSystem.self)
    }
}

struct CameraRenderPlugin: RenderWorldPlugin {
    func setup(in world: RenderWorld) {
        world.renderGraph.addNode(CameraRenderNode())
    }
}

struct CameraRenderNode: RenderNode {
    
    static let query = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
    
    func execute(context: Context) async -> [RenderSlotValue] {
        await context.world.performQuery(Self.query).concurrent.forEach { entity in
            let compontents = entity.components
            guard let camera = compontents[Camera.self], camera.isActive else {
                return
            }

            await context.runSubgraph(by: Scene2DPlugin.renderGraph, inputs: [
                RenderSlotValue(name: Scene2DPlugin.InputNode.view, value: .entity(entity))
            ], viewEntity: entity)
        }

        return []
    }
}
