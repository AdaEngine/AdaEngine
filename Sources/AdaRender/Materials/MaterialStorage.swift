//
//  MaterialStorage.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/2/23.
//

import AdaAssets
import AdaUtils

// TODO: I don't like that solution
// - Remove or replace RenderEngine
// - Should be a class or be open for inheritance?
open class MaterialStorageData {
    public var reflectionData: ShaderReflectionData = ShaderReflectionData()
    public var uniformBufferSet: [String : UniformBufferSet] = [:]
    public var textures: [String : Texture] = [:]
    public var samplers: [String : any Sampler] = [:]
    public init() {}

    public func updateUniformBuffers(from module: ShaderModule) {
        self.reflectionData.merge(module.reflectionData)
        
        module.reflectionData.shaderBuffers.forEach { (bufferName, bufferDesc) in
            if self.uniformBufferSet[bufferName] == nil {
                let bufferSet = unsafe RenderEngine.shared.renderDevice.createUniformBufferSet()
                bufferSet.label = "\(module.assetName) \(bufferDesc.name) \(bufferDesc.shaderStage)"
                bufferSet.initBuffers(length: bufferDesc.size, binding: bufferDesc.binding, set: 0)
                
                self.uniformBufferSet[bufferName] = bufferSet
            }
        }
        
        module.reflectionData.resources.forEach { (resourceName, resourceDesc) in
            if self.textures[resourceName] == nil {
                self.textures[resourceName] = Texture2D.whiteTexture
            }
        }
    }
}

public final class MaterialStorage {
    public nonisolated(unsafe) static let shared: MaterialStorage = MaterialStorage()
    private var materialData: [RID: MaterialStorageData] = [:]
    
    private init() {}
    
    // MARK: - Material
    
    public func setValue<T: ShaderUniformValue>(_ value: T, for name: String, in material: Material) {
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
            frameIndex: 0
        )
        
        unsafe withUnsafePointer(to: value) { pointer in
            let dataPtr = unsafe UnsafeMutableRawPointer(mutating: UnsafeRawPointer(pointer))
            unsafe buffer?.setData(dataPtr, byteCount: member.size, offset: member.offset)
        }
    }
    
    public func getValue<T: ShaderUniformValue>(for name: String, in material: Material) -> T? {
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
            frameIndex: 0
        )
        
        return unsafe buffer?.contents().load(fromByteOffset: member.offset, as: T.self)
    }

    public func getUniformDescription(for name: String, in material: MaterialStorageData) -> ShaderResource.ShaderBuffer? {
        let reflectionData = material.reflectionData
        
        for buffer in reflectionData.shaderBuffers.values {
            if buffer.members[name] != nil {
                return buffer
            }
        }
        
        return nil
    }
    
    public func setTexture(_ texture: Texture, for name: String, in material: Material) {
        guard let data = self.materialData[material.rid] else {
            return
        }
        
        guard let samplerDescription = self.getResourceDescription(for: name, in: data) else {
            return
        }
        data.textures[samplerDescription.name] = texture
    }

    public func setSampler(_ sampler: any Sampler, for name: String, in material: Material) {
        guard let data = self.materialData[material.rid] else {
            return
        }
        
        guard let samplerDescription = self.getResourceDescription(for: name, in: data) else {
            return
        }

        data.samplers[samplerDescription.name] = sampler
    }

    public func getSampler(for name: String, in material: Material) -> (any Sampler)? {
        guard let data = self.materialData[material.rid] else {
            return nil
        }
        
        guard let samplerDescription = self.getResourceDescription(for: name, in: data) else {
            return nil
        }

        return data.samplers[samplerDescription.name]
    }
    
    public func getTexture(for name: String, in material: Material) -> Texture? {
        guard let data = self.materialData[material.rid] else {
            return nil
        }
        
        guard let samplerDescription = self.getResourceDescription(for: name, in: data) else {
            return nil
        }
        
        return data.textures[samplerDescription.name]
    }
    
    public func getResourceDescription(for name: String, in material: MaterialStorageData) -> ShaderResource.ImageSampler? {
        let reflectionData = material.reflectionData
        return reflectionData.resources[name]
    }
    
    public func setMaterialData(_ materialData: MaterialStorageData, for material: Material) {
        self.materialData[material.rid] = materialData
    }
    
    public func getMaterialData(for material: Material) -> MaterialStorageData? {
        return self.materialData[material.rid]
    }
}
