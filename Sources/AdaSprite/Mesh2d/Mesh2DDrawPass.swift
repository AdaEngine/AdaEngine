//
//  Mesh2DDrawPass.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/2/23.
//

import AdaECS
@_spi(Internal) import AdaRender
import AdaCorePipelines
import Math

struct Mesh2DUniform {
    let model: Transform3D
    let modelInverseTranspose: Transform3D
}

/// Contians logic for drawing 2D Meshes.
public struct Mesh2DDrawPass: DrawPass {
    public typealias Item = Transparent2DRenderItem

    public static let meshUniformBinding: Int = 2
    
    public init() { }
    
    public func render(
        with renderEncoder: RenderCommandEncoder,
        world: World,
        view: Entity,
        item: Transparent2DRenderItem
    ) throws {
        guard let entity = world.getEntityByID(item.entity) else {
            return
        }
        guard let meshComponent = entity.components[ExctractedMeshPart2d.self] else {
            return
        }
        var part = meshComponent.part
        guard let materialData = unsafe MaterialStorage.shared.getMaterialData(for: meshComponent.material) else {
            return
        }

        renderEncoder.pushDebugName("Mesh 2D Render")
        defer {
            renderEncoder.popDebugName()
        }

        for (uniformName, buffer) in materialData.reflectionData.shaderBuffers {
            guard let uniformBuffer = materialData.uniformBufferSet[uniformName]?
                .getBuffer(
                    binding: buffer.binding,
                    set: 0,
                    frameIndex: RenderEngine.shared.currentFrameIndex
                ) else {
                continue
            }
            
            if buffer.shaderStage.contains(.vertex) {
                renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: buffer.binding)
            }
            
            if buffer.shaderStage.contains(.fragment) {
                renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: buffer.binding)
            }
        }
        
        for (resourceName, resource) in materialData.reflectionData.resources {
            guard let textures = materialData.textures[resourceName] else {
                continue
            }
            
            for texture in textures {
                renderEncoder.setFragmentTexture(texture, index: resource.binding)
                renderEncoder.setFragmentSamplerState(texture.sampler, index: resource.binding)
            }
        }
        unsafe withUnsafeBytes(of: meshComponent.modelUniform) { buffer in
            unsafe renderEncoder.setVertexBytes(buffer.baseAddress!, length: buffer.count, index: Self.meshUniformBinding)
        }

        part.vertexBuffer.label = "Part Vertex Buffer"
        renderEncoder.setVertexBuffer(part.vertexBuffer, offset: 0, index: 0)
        renderEncoder.setIndexBuffer(part.indexBuffer, offset: 0)
        renderEncoder.setRenderPipelineState(item.renderPipeline)
        
        renderEncoder.drawIndexed(indexCount: part.indexCount, indexBufferOffset: 0, instanceCount: 1)
    }
}

extension Mesh.PrimitiveTopology {
    var indexPrimitive: IndexPrimitive {
        switch self {
        case .points:
            return .points
        case .triangleList:
            return .triangle
        case .triangleStrip:
            return .triangleStrip
        case .lineList:
            return .line
        case .lineStrip:
            return .lineStrip
        }
    }
}
