//
//  ShaderSource.swift
//  
//
//  Created by v.prusakov on 3/13/23.
//

import SPIRVCompiler

public enum ShaderLanguage {
    
    /// Vulkan, OpenGL, WebGL
    case glsl
    
    /// High Level Shading Language (DirectX)
    case hlsl
    
    /// Metal Shading Language
    case msl
    
    /// WebGPU Shading Language
    case wgsl
}

public enum ShaderStage: String, Hashable {
    case vertex
    case fragment
    case compute
    case tesselationControl
    case tesselationEvaluation
    case max
}

public final class ShaderSource {
    
    enum Error: LocalizedError {
        case failedToRead(String)
        
        var errorDescription: String? {
            switch self {
            case .failedToRead(let path):
                return "[ShaderSource] Failed to read file at path \(path)."
            }
        }
    }
    
    public private(set) var language: ShaderLanguage = .glsl
    private var sources: [ShaderStage: String] = [:]
    
    // TODO: Add support for wgsl
    public init(from fileURL: URL) throws {
        guard let data = FileSystem.current.readFile(at: fileURL) else {
            throw Error.failedToRead(fileURL.path)
        }
        
        let sourceCode = String(data: data, encoding: .utf8) ?? ""
        self.language = ShaderUtils.shaderLang(from: fileURL.pathExtension)
        
        switch language {
        case .glsl:
            self.sources = try ShaderUtils.processGLSLShader(source: sourceCode)
        default:
            self.sources = [.max: sourceCode]
        }
    }
    
    public init(source: String, lang: ShaderLanguage = .glsl) throws {
        self.sources = try ShaderUtils.processGLSLShader(source: source)
        self.language = lang
    }
    
    public init() { }
    
    public func setSource(_ source: String, for stage: ShaderStage) {
        self.sources[stage] = source
    }
    
    public func getSource(for stage: ShaderStage) -> String? {
        return self.sources[stage]
    }
    
    public var stages: [ShaderStage] {
        return Array(self.sources.keys)
    }
}
