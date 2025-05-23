//
//  ShaderModule.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/14/23.
//

import Foundation

public final class ShaderModule: Asset, @unchecked Sendable {
    
    private var shaders: [ShaderStage: Shader] = [:]
    var reflectionData: ShaderReflectionData
    
    init(shaders: [ShaderStage : Shader] = [:], reflectionData: ShaderReflectionData) {
        self.shaders = shaders
        self.reflectionData = reflectionData
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
    
    public func setMacro(_ name: String, value: String, for shaderStage: ShaderStage) {
        self.shaders[shaderStage]?.setMacro(name, value: value)
    }
    
    // Resource
    
    public var assetMetaInfo: AssetMetaInfo?
    
    // TODO: Add init from spir-v
    public init(asset decoder: AssetDecoder) throws {
        let filePath = decoder.assetMeta.filePath
        let module = try ShaderCompiler(from: filePath).compileShaderModule()
        self.shaders = module.shaders
        self.reflectionData = module.reflectionData
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalError("TODO")
    }
    
    public static func extensions() -> [String] {
        ["mat"]
    }
}

public extension ShaderModule {
    static func create(from fileUrl: URL) throws -> ShaderModule {
        try ShaderCompiler(from: fileUrl).compileShaderModule()
    }
}
