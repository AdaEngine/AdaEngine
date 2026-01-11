//
//  ShaderModule.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/14/23.
//

import AdaAssets
import AdaUtils
import Foundation

/// A shader module that stores shaders.
public final class ShaderModule: Asset, @unchecked Sendable {
    
    /// The shaders in the shader module.
    private var shaders: [ShaderStage: Shader] = [:]

    /// The reflection data of the shader module.
    var reflectionData: ShaderReflectionData
    
    /// Initialize a new shader module.
    ///
    /// - Parameters:
    ///   - shaders: The shaders in the shader module.
    init(shaders: [ShaderStage : Shader] = [:], reflectionData: ShaderReflectionData) {
        self.shaders = shaders
        self.reflectionData = reflectionData
    }
    
    /// Add a shader to the shader module.
    ///
    /// - Parameters:
    ///   - shader: The shader to add.
    ///   - stage: The stage of the shader.
    public func addShader(_ shader: Shader, for stage: ShaderStage) {
        self.shaders[stage] = shader
    }
    
    /// Get a shader from the shader module.
    ///
    /// - Parameter stage: The stage of the shader.
    /// - Returns: The shader.
    public func getShader(for stage: ShaderStage) -> Shader? {
        return self.shaders[stage]
    }
    
    /// The stages of the shader module.
    public var stages: [ShaderStage] {
        return Array(self.shaders.keys)
    }
    
    /// Set a macro for a shader stage.
    ///
    /// - Parameters:
    ///   - name: The name of the macro.
    ///   - value: The value of the macro.
    ///   - shaderStage: The stage of the shader.
    public func setMacro(_ name: String, value: String, for shaderStage: ShaderStage) {
        self.shaders[shaderStage]?.setMacro(name, value: value)
    }
    
    /// The asset meta info of the shader module.
    public var assetMetaInfo: AssetMetaInfo?
    
    /// Initialize a new shader module from a decoder.
    ///
    /// - Parameter decoder: The decoder to initialize the shader module from.
    /// - Throws: An error if the shader module cannot be initialized from the decoder.
    public init(from decoder: AssetDecoder) throws {
        let filePath = decoder.assetMeta.filePath
        let module = try ShaderCompiler(from: filePath).compileShaderModule()
        self.shaders = module.shaders
        self.reflectionData = module.reflectionData
    }
    
    /// Encode the shader module to an encoder.
    ///
    /// - Parameter encoder: The encoder to encode the shader module to.
    /// - Throws: An error if the shader module cannot be encoded to the encoder.
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalError("TODO")
    }
    
    /// The extensions of the shader module.
    public static func extensions() -> [String] {
        ["mat"]
    }
}

public extension ShaderModule {
    /// Create a new shader module from a file url.
    ///
    /// - Parameter fileUrl: The file url to create the shader module from.
    /// - Returns: The shader module.
    static func create(from fileUrl: URL) async throws -> ShaderModule {
        try await ShaderCompiler(from: fileUrl).compileShaderModule()
    }
}
