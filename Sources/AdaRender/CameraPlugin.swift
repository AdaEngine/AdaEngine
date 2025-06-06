//
//  CameraPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

import AdaApp
import AdaECS
import AdaTransform
import AdaUtils

public struct CameraPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        Camera.registerComponent()        
        app.addSystem(CameraSystem.self)

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        renderWorld.mainWorld
            .addSystem(ExtractCameraSystem.self, on: .extract)
            .getMutableResource(RenderGraph.self)?
            .wrappedValue?
            .addNode(CameraRenderNode())
    }
}

struct CameraRenderNode: RenderNode {

    @Query<Entity, Camera, Transform>
    private var query

    func execute(context: inout Context) async -> [RenderSlotValue] {
        context.world.performQuery(_query).forEach { (entity, camera, transform) in
            guard camera.isActive else {
                return
            }

             context.runSubgraph(by: Scene2DPlugin.renderGraph, inputs: [
                RenderSlotValue(name: Scene2DPlugin.InputNode.view, value: .entity(entity))
            ], viewEntity: entity)
        }

        return []
    }
}
