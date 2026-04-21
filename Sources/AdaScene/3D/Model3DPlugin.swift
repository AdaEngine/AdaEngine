//
//  Model3DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import AdaApp
import AdaECS
@_spi(Internal) import AdaRender
import AdaTransform
import Math

/// Plugin for extracting 3D models from scene to RenderWorld.
public struct Model3DPlugin: Plugin {

    public init() {}
    
    public func setup(in app: AppWorlds) {
        Mesh3DComponent.registerComponent()
        
        guard let renderWorld = app.getSubworldBuilder(by: .renderWorld) else {
            return
        }
        
        renderWorld
            .insertResource(RenderItems<Opaque3DRenderItem>())
            .insertResource(Model3DDrawPass())
            .addSystem(ExtractModel3DSystem.self, on: .extract)
            .addSystem(ClearOpaque3DRenderItemsSystem.self, on: .preUpdate)
    }
}

@System
func ClearOpaque3DRenderItems(
    _ renderItems: ResMut<RenderItems<Opaque3DRenderItem>>
) {
    renderItems.items.removeAll(keepingCapacity: true)
}

@System
func ExtractModel3D(
    _ query: Extract<Query<Entity, Mesh3DComponent, GlobalTransform>>,
    _ renderItems: ResMut<RenderItems<Opaque3DRenderItem>>,
    _ drawPass: Res<Model3DDrawPass>
) {
    query.wrappedValue.forEach { entity, mesh3d, transform in
        let mesh = mesh3d.mesh
        for (modelIndex, model) in mesh.models.enumerated() {
            for (partIndex, part) in model.parts.enumerated() {
                let material = mesh3d.materials[part.materialIndex]
                
                renderItems.items.append(
                    Opaque3DRenderItem(
                        entity: entity.id,
                        drawPass: drawPass.wrappedValue,
                        sortKey: 0,
                        modelIndex: modelIndex,
                        partIndex: partIndex,
                        mesh: mesh,
                        material: material,
                        worldTransform: transform.matrix
                    )
                )
            }
        }
    }
}

public final class Model3DDrawPass: DrawPass, @unchecked Sendable {
    public init() {}
    
    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: Opaque3DRenderItem
    ) throws {
        // FIXME: (Vlad) Implement 3D rendering
    }
}
