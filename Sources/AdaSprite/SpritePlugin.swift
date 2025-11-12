//
//  SpritePlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 2/23/23.
//

import AdaApp
import AdaECS
import AdaRender

/// Plugin for exctracting sprites from scene to RenderWorld.
public struct SpritePlugin: Plugin {

    public init() {}
    
    public func setup(in app: AppWorlds) {
        SpriteComponent.registerComponent()

        app
            .addSystem(UpdateBoundingsSystem.self, on: .postUpdate)
            .main
            .registerRequiredComponent(SpriteComponent.self, Visibility.self)
            .registerRequiredComponent(Mesh2DComponent.self, Visibility.self)

        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }

        renderWorld
            .insertResource(ExtractedSprites(sprites: []))
            .insertResource(SpriteRenderPipeline())
//            .insertResource(SpriteDrawData(
//                vertexBuffer: BufferData<SpriteVertexData>(label: "SpriteRenderSystem_IndexBuffer", elements: []),
//                indexBuffer: BufferData<UInt32>(elements: [])
//            )
//            )
            .insertResource(SpriteDrawPass())
            .addSystem(ExtractSpriteSystem.self, on: .extract)
            .addSystem(ExctractMesh2DSystem.self, on: .extract)
            .addSystem(SpriteRenderSystem.self, on: .render)
    }
}
