//
//  CameraPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/19/23.
//

import AdaApp
import AdaECS
import AdaRender
import AdaTransform
import AdaUtils

public struct CameraPlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        app
            .addSystem(CameraSystem.self)
            .addSystem(ExtractCameraSystem.self)

        guard let subworld = app.getSubworldBuilder(by: "RenderWorld") else {
            return
        }

        Task {
            await subworld.mainWorld
                .getResource(RenderGraph.self)?
                .addNode(CameraRenderNode())
        }
    }
}

struct CameraRenderPlugin: Plugin {
    public func setup(in app: AppWorlds) {

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
