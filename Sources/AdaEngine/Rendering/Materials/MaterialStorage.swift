//
//  MaterialStorage.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/2/23.
//

class MaterialStorageData {
    var reflectionData: ShaderReflectionData = ShaderReflectionData()
    var uniformBufferSet: [String : UniformBufferSet] = [:]
    var textures: [String : [Texture]] = [:]
    
    func updateUniformBuffers(from module: ShaderModule) {
        self.reflectionData.merge(module.reflectionData)
        
        module.reflectionData.shaderBuffers.forEach { (bufferName, bufferDesc) in
            if self.uniformBufferSet[bufferName] == nil {
                let bufferSet = RenderEngine.shared.renderDevice.createUniformBufferSet()
                bufferSet.label = "\(module.resourceName) \(bufferDesc.name) \(bufferDesc.shaderStage)"
                bufferSet.initBuffers(length: bufferDesc.size, binding: bufferDesc.binding, set: 0)
                
                self.uniformBufferSet[bufferName] = bufferSet
            }
        }
        
        module.reflectionData.resources.forEach { (resourceName, resourceDesc) in
            if self.textures[resourceName] == nil {
                self.textures[resourceName] = [Texture].init(
                    repeating: Texture2D.whiteTexture,
                    count: resourceDesc.arraySize > 0 ? resourceDesc.arraySize : 1
                )
            }
        }
    }
}

final class MaterialStorage {
    
    static let shared: MaterialStorage = MaterialStorage()
    
    private var materialData: [RID: MaterialStorageData] = [:]
    
    private init() {}
    
    // MARK: - Material
    
    func setValue<T: ShaderUniformValue>(_ value: T, for name: String, in material: Material) {
        guard let data = self.materialData[material.rid] else {
            return
        }
        
        guard let bufferDesc = self.getUniformDescription(for: name, in: data), let member = bufferDesc.members[name] else {
            return
        }
        
        assert(T.shaderValueType == member.type, "Failed to set value with type \(T.shaderValueType) to property with type \(member.type)")
        
        let buffer = data.uniformBufferSet[bufferDesc.name]?.getBuffer(
            binding: member.binding,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )
        
        withUnsafePointer(to: value) { pointer in
            let dataPtr = UnsafeMutableRawPointer(mutating: UnsafeRawPointer(pointer))
            buffer?.setData(dataPtr, byteCount: member.size, offset: member.offset)
        }
    }
    
    func getValue<T: ShaderUniformValue>(for name: String, in material: Material) -> T? {
        guard let data = self.materialData[material.rid] else {
            return nil
        }
        
        guard let bufferDesc = self.getUniformDescription(for: name, in: data), let member = bufferDesc.members[name] else {
            return nil
        }
        
        assert(T.shaderValueType == member.type, "Failed to get value with type \(T.shaderValueType) from property with type \(member.type)")
        
        let buffer = data.uniformBufferSet[bufferDesc.name]?.getBuffer(
            binding: member.binding,
            set: 0,
            frameIndex: RenderEngine.shared.currentFrameIndex
        )
        
        return buffer?.contents().load(fromByteOffset: member.offset, as: T.self)
    }
    
    @inlinable
    func getUniformDescription(for name: String, in material: MaterialStorageData) -> ShaderResource.ShaderBuffer? {
        let reflectionData = material.reflectionData
        
        for buffer in reflectionData.shaderBuffers.values {
            if buffer.members[name] != nil {
                return buffer
            }
        }
        
        return nil
    }
    
    func setResources(_ textures: [Texture], for name: String, in material: Material) {
        guard let data = self.materialData[material.rid] else {
            return
        }
        
        guard let sampler = self.getResourceDescription(for: name, in: data) else {
            return
        }
        
        for (index, texture) in textures.enumerated() {
            data.textures[sampler.name]?[index] = texture
        }
    }
    
    func getResources(for name: String, in material: Material) -> [Texture] {
        guard let data = self.materialData[material.rid] else {
            return []
        }
        
        guard let sampler = self.getResourceDescription(for: name, in: data) else {
            return []
        }
        
        return data.textures[sampler.name] ?? []
    }
    
    @inlinable
    func getResourceDescription(for name: String, in material: MaterialStorageData) -> ShaderResource.ImageSampler? {
        let reflectionData = material.reflectionData
        return reflectionData.resources[name]
    }
    
    func setMaterialData(_ materialData: MaterialStorageData, for material: Material) {
        self.materialData[material.rid] = materialData
    }
    
    func getMaterialData(for material: Material) -> MaterialStorageData? {
        return self.materialData[material.rid]
    }
}
