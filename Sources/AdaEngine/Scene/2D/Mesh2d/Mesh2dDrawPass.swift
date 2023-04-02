//
//  Mesh2DDrawPass.swift
//  
//
//  Created by v.prusakov on 4/2/23.
//

import Math

struct Mesh2DUniform {
    let model: Transform3D
    let modelInverseTranspose: Transform3D
}

struct Mesh2DDrawPass: DrawPass {
    
    let meshUniformBufferSet: UniformBufferSet
    
    static let meshUniformBinding: Int = 2
    
    init() {
        self.meshUniformBufferSet = RenderEngine.shared.makeUniformBufferSet()
        self.meshUniformBufferSet.initBuffers(for: Mesh2DUniform.self, binding: Self.meshUniformBinding, set: 0)
    }
    
    func render(in context: Context, item: Transparent2DRenderItem) throws {
        let meshComponent = item.entity.components[ExctractedMeshPart2d.self]!
        
        let part = meshComponent.part
        let drawList = context.drawList
        
        guard let materialData = MaterialStorage.shared.getMaterialData(for: meshComponent.material) else {
            return
        }
        
        guard let cameraViewUniform = context.view.components[GlobalViewUniformBufferSet.self] else {
            return
        }
        
        let uniformBuffer = cameraViewUniform.uniformBufferSet.getBuffer(binding: BufferIndex.baseUniform, set: 0, frameIndex: context.device.currentFrameIndex)
        context.drawList.appendUniformBuffer(uniformBuffer)
        
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
        
        let meshUniformBuffer = self.meshUniformBufferSet.getBuffer(
            binding: Self.meshUniformBinding,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )
        
        meshUniformBuffer.setData(meshComponent.modelUniform)
        
        drawList.appendUniformBuffer(meshUniformBuffer)
        
        drawList.appendVertexBuffer(part.vertexBuffer)
        drawList.bindIndexBuffer(part.indexBuffer)
        drawList.bindIndexPrimitive(part.primitiveTopology.indexPrimitive)
        drawList.bindRenderPipeline(item.renderPipeline)
        
        drawList.drawIndexed(indexCount: part.indexCount, instancesCount: 1)
        drawList.popDebugName()
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
