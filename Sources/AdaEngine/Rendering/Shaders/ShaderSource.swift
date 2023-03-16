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

// TODO: Add support for wgsl

public enum ShaderStage: String, Hashable {
    case vertex
    case fragment
    case compute
    case tesselationControl
    case tesselationEvaluation
    case max
}

/// Contains collection of shader sources splitted by stages.
///
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
    
    /// Provide search path for includes in your shader.
    public enum IncludeSearchPath {
        case _local(URL)
        // ModuleName, Path to Module Search Path
        case _module(String, URL)
    }
    
    /// Defined language of shader sources.
    public private(set) var language: ShaderLanguage = .glsl
    
    private var sources: [ShaderStage: String] = [:]
    private(set) var includeSearchPaths: [ShaderSource.IncludeSearchPath] = []
    
    /// Create a shader source from a file. Automatic detect language and split to stages (for GLSL only).
    public init(from fileURL: URL) throws {
        guard let data = FileSystem.current.readFile(at: fileURL) else {
            throw Error.failedToRead(fileURL.path)
        }
        
        let sourceCode = String(data: data, encoding: .utf8) ?? ""
        self.language = ShaderUtils.shaderLang(from: fileURL.pathExtension)
        self.includeSearchPaths = [.local(fileURL.deletingLastPathComponent())]
        
        switch language {
        case .glsl:
            self.sources = try ShaderUtils.processGLSLShader(source: sourceCode)
        default:
            self.sources = [.max: sourceCode]
        }
    }
    
    /// Create a shader source from raw string.
    /// - Parameter source: A source code of shader.
    /// - Parameter lang: Set the source code lang. GLSL by default.
    /// - Parameter includeSearchPath: If you source needs your own includes, provide search path for them. Empty by default.
    public init(
        source: String,
        lang: ShaderLanguage = .glsl,
        includeSearchPaths: [ShaderSource.IncludeSearchPath] = []
    ) throws {
        self.sources = try ShaderUtils.processGLSLShader(source: source)
        self.includeSearchPaths = includeSearchPaths
        self.language = lang
    }
    
    public init() { }
    
    public func setSource(_ source: String, for stage: ShaderStage) {
        self.sources[stage] = source
    }
    
    public func getSource(for stage: ShaderStage) -> String? {
        return self.sources[stage]
    }
    
    /// Return collection of stages available in this shader source.
    public var stages: [ShaderStage] {
        return Array(self.sources.keys)
    }
}

public extension ShaderSource.IncludeSearchPath {
    /// Create search path for ""-style include.
    ///
    /// Example:
    /// ```
    /// #include "PATH_TO_FILE"
    /// ```
    static func local(_ fileDirectory: URL) -> Self {
        return ._local(fileDirectory)
    }
    
    /// Create search path for <>-style include.
    ///
    /// Example:
    /// ```
    /// #include <MODULE_NAME/PATH_TO_FILE>
    /// ```
    static func module(name: String, modulePath: URL) -> Self {
        return ._module(name, modulePath)
    }
}
