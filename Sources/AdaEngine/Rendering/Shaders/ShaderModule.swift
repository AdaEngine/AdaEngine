//
//  ShaderModule.swift
//  
//
//  Created by v.prusakov on 3/14/23.
//

import Foundation

public final class ShaderModule: Resource {
    
    private var shaders: [ShaderStage: Shader] = [:]
    
    public init(shaders: [ShaderStage : Shader] = [:]) {
        self.shaders = shaders
    }
    
    public func addShader(_ shader: Shader, for stage: ShaderStage) {
        self.shaders[stage] = shader
    }
    
    public func getShader(for stage: ShaderStage) -> Shader? {
        return self.shaders[stage]
    }
    
    public var stages: [ShaderStage] {
        return Array(self.shaders.keys)
    }
    
    // Resource
    
    public var resourceName: String = ""
    public var resourcePath: String = ""
    public static var resourceType: ResourceType = .material
    
    // TODO: Add init from spir-v
    public init(asset decoder: AssetDecoder) throws {
        let filePath = decoder.assetMeta.filePath
        let module = try ShaderCompiler(from: filePath).compileShaderModule()
        self.shaders = module.shaders
        self.resourceName = filePath.lastPathComponent
        self.resourcePath = filePath.path
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalError("TODO")
    }
}

public extension ShaderModule {
    static func create(from fileUrl: URL) throws -> ShaderModule {
        try ShaderCompiler(from: fileUrl).compileShaderModule()
    }
}