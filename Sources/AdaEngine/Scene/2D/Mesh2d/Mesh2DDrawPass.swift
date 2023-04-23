//
//  Mesh2DDrawPass.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/2/23.
//

import Math

struct Mesh2DUniform {
    let model: Transform3D
    let modelInverseTranspose: Transform3D
}

/// Contians logic for drawing 2D Meshes.
public struct Mesh2DDrawPass: DrawPass {
    
    public static let meshUniformBinding: Int = 2
    
    public init() { }
    
    public func render(in context: Context, item: Transparent2DRenderItem) throws {
        let meshComponent = item.entity.components[ExctractedMeshPart2d.self]!
        
        let part = meshComponent.part
        let drawList = context.drawList
        
        guard let materialData = MaterialStorage.shared.getMaterialData(for: meshComponent.material) else {
            return
        }
        
        guard let cameraViewUniform = context.view.components[GlobalViewUniformBufferSet.self] else {
            return
        }
        
        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(
            binding: GlobalBufferIndex.viewUniform,
            set: 0,
            frameIndex: context.device.currentFrameIndex
        )
        drawList.appendUniformBuffer(uniformBuffer, for: .vertex)
        
        drawList.pushDebugName("Mesh 2D Render")
        
        for (uniformName, buffer) in materialData.reflectionData.shaderBuffers {
            guard let uniformBuffer = materialData.uniformBufferSet[uniformName]?.getBuffer(binding: buffer.binding, set: 0, frameIndex: RenderEngine.shared.currentFrameIndex) else {
                continue
            }
            
            if buffer.shaderStage.contains(.vertex) {
                drawList.appendUniformBuffer(uniformBuffer, for: .vertex)
            }
            
            if buffer.shaderStage.contains(.fragment) {
                drawList.appendUniformBuffer(uniformBuffer, for: .fragment)
            }
        }
        
        for (resourceName, resource) in materialData.reflectionData.resources {
            guard let textures = materialData.textures[resourceName] else {
                continue
            }
            
            for texture in textures {
                drawList.bindTexture(texture, at: resource.binding)
            }
        }
        
        let meshUniformBuffer = context.device.makeUniformBuffer(Mesh2DUniform.self, binding: Self.meshUniformBinding)
        meshUniformBuffer.setData(meshComponent.modelUniform)
        
        meshUniformBuffer.setData(meshComponent.modelUniform)
        
        drawList.appendUniformBuffer(meshUniformBuffer, for: .vertex)
        
        drawList.appendVertexBuffer(part.vertexBuffer)
        drawList.bindIndexBuffer(part.indexBuffer)
        drawList.bindIndexPrimitive(part.primitiveTopology.indexPrimitive)
        drawList.bindRenderPipeline(item.renderPipeline)
        
        drawList.drawIndexed(indexCount: part.indexCount, instancesCount: 1)
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
