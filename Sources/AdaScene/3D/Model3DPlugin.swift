//
//  Model3DPlugin.swift
//  AdaEngine
//
//  Created by v.prusakov on 04/21/26.
//

import AdaApp
import AdaECS
import AdaCorePipelines
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
            .insertResource(RenderPipelines(configurator: Flat3DPipeline()))
            .insertResource(Model3DDrawPass())
            .addSystem(ExtractModel3DSystem.self, on: .extract)
    }
}

@System
func ExtractModel3D(
    _ query: Extract<Query<Entity, Mesh3DComponent, GlobalTransform>>,
    _ renderItems: ResMut<RenderItems<Opaque3DRenderItem>>,
    _ drawPass: Res<Model3DDrawPass>
) {
    renderItems.items.removeAll(keepingCapacity: true)

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
        let part = item.mesh.models[item.modelIndex].parts[item.partIndex]
        let renderDevice = world.getResource(RenderDeviceHandler.self)?.renderDevice
        guard let renderDevice else {
            return
        }

        let pipelines = world.getRefResource(RenderPipelines<Flat3DPipeline>.self)
        let pipeline = pipelines.wrappedValue.pipeline(for: part.vertexDescriptor, device: renderDevice)
        let materialColor = (item.material as? PBRMaterial)?.baseColorFactor ?? .one
        let modelUniform = Flat3DModelUniform(
            modelMatrix: item.worldTransform,
            color: materialColor
        )

        renderEncoder.setRenderPipelineState(pipeline)
        renderEncoder.setVertexBuffer(part.vertexBuffer, offset: 0, slot: 0)
        renderEncoder.setVertexBuffer(modelUniform, slot: 3)
        renderEncoder.setIndexBuffer(part.indexBuffer, offset: 0)
        renderEncoder.drawIndexed(indexCount: part.indexCount, indexBufferOffset: 0, instanceCount: 1)
    }
}

private struct Flat3DModelUniform: Sendable {
    let modelMatrix: Transform3D
    let color: Vector4
}
