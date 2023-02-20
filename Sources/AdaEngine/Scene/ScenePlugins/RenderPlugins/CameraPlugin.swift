//
//  CameraPlugin.swift
//  
//
//  Created by v.prusakov on 2/19/23.
//

struct CameraPlugin: ScenePlugin {
    func setup(in scene: Scene) {
        scene.addSystem(CameraSystem.self)
        scene.sceneRenderGraph.addNode(with: "CameraRenderNode", node: CameraRenderNode())
    }
}

struct CameraRenderNode: RenderNode {
    
    static let query = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
    
    func execute(context: Context) -> [RenderSlotValue] {
        context.scene.performQuery(Self.query).forEach { entity in
            guard let camera = entity.components[Camera.self], camera.isActive else {
                return
            }
            
            context.runSubgraph(by: Scene2DPlugin.renderGraph, inputs: [
                RenderSlotValue(name: Scene2DPlugin.InputNode.view, value: .entity(entity))
            ])
        }
        
        return []
    }
}
