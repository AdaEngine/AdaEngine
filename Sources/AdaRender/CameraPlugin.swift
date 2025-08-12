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

        renderWorld
            .addSystem(ExtractCameraSystem.self, on: .extract)
            .addSystem(ConfigurateRenderViewTargetSystem.self, on: .update)
            .getMutableResource(RenderGraph.self)
            .wrappedValue?
            .addNode(CameraRenderNode())
    }
}

@System
func ConfigurateRenderViewTarget(
    _ query: Query<Entity, Camera, Ref<RenderViewTarget>>,
    _ renderDevice: Res<RenderDeviceHandler>
) {
    query.forEach { (entity, camera, renderViewTarget) in
        renderViewTarget.mainTexture = renderDevice.createTexture(
            size: camera.viewport.size,
            format: .rgba8Unorm
        )


        renderViewTarget.outputTexture = renderDevice.createTexture(
            size: camera.viewport.size,
            format: .rgba8Unorm
        )
    }
}

struct CameraRenderNode: RenderNode {

    @Query<Entity, Camera>
    private var query

    func update(from world: World) {
        query.update(from: world)
    }

    func execute(context: inout Context, renderContext: RenderContext) async -> [RenderSlotValue] {
        query.forEach { (entity, camera) in
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
