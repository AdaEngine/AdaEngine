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

struct CameraRenderPlugin: ScenePlugin {
    func setup(in scene: Scene) async {
        await Application.shared.renderWorld.renderGraph.addNode(with: "CameraRenderNode", node: CameraRenderNode())
    }
}

struct CameraRenderNode: RenderNode {
    
    static let query = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
    
    func execute(context: Context) async -> [RenderSlotValue] {
        await context.world.performQuery(Self.query).concurrent.forEach { entity in
            guard let camera = entity.components[Camera.self], camera.isActive else {
                return
            }

            await context.runSubgraph(by: Scene2DPlugin.renderGraph, inputs: [
                RenderSlotValue(name: Scene2DPlugin.InputNode.view, value: .entity(entity))
            ])
            
            await context.runSubgraph(by: UIRenderPlugin.renderGraph, inputs: [
                RenderSlotValue(name: UIRenderPlugin.InputNode.view, value: .entity(entity))
            ])

            // TODO: blit to window
        }

        return []
    }
}
