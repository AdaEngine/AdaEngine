//
//  CameraPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

struct CameraPlugin: ScenePlugin {
    func setup(in scene: Scene) async {
        scene.addSystem(CameraSystem.self)
        scene.addSystem(ExtractCameraSystem.self)
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
            guard let camera = entity.components[Camera.self], camera.isActive else {
                return
            }

            context.runSubgraph(by: Scene2DPlugin.renderGraph, inputs: [
                RenderSlotValue(name: Scene2DPlugin.InputNode.view, value: .entity(entity))
            ], viewEntity: entity)

            // TODO: blit to window
        }

        return []
    }
}
