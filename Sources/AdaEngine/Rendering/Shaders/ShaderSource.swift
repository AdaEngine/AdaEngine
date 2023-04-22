//
//  ShaderSource.swift
//  
//
//  Created by v.prusakov on 3/13/23.
//

import SPIRVCompiler

public enum ShaderLanguage: String {
    
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

public enum ShaderStage: String, Hashable, Codable {
    case vertex
    case fragment
    case compute
    case tesselationControl
    case tesselationEvaluation
    case max
}

/// Contains collection of shader sources splitted by stages.
public final class ShaderSource: Resource {
    
    enum Error: LocalizedError {
        case failedToRead(String)
        case message(String)
        
        var errorDescription: String? {
            switch self {
            case .failedToRead(let path):
                return "[ShaderSource] Failed to read file at path \(path)."
            case .message(let message):
                return "[ShaderSource] \(message)"
            }
        }
    }
    
    /// Provide search path for includes in your shader.
    public enum IncludeSearchPath: Equatable, Codable {
        case _local(URL)
        // ModuleName, Path to Module Search Path
        case _module(String, URL)
    }
    
    /// Defined language of shader sources.
    public private(set) var language: ShaderLanguage = .glsl
    
    private var sources: [ShaderStage: String] = [:]
    private var entryPoints: [ShaderStage: String] = [:]
    
    /// Contains include search paths for shaders.
    public var includeSearchPaths: [ShaderSource.IncludeSearchPath] = []
    
    /// Contains url to shader sources if ShaderSource was created from file.
    private(set) var fileURL: URL?
    
    /// Create a shader source from a file. Automatic detect language and split to stages (for GLSL only).
    public init(from fileURL: URL) throws {
        guard let data = FileSystem.current.readFile(at: fileURL) else {
            throw Error.failedToRead(fileURL.path)
        }
        
        self.fileURL = fileURL
        
        let sourceCode = String(data: data, encoding: .utf8) ?? ""
        self.language = ShaderUtils.shaderLang(from: fileURL.pathExtension)
        self.includeSearchPaths = [.local(fileURL.deletingLastPathComponent())]
        
        switch language {
        case .glsl:
            self.sources = try ShaderUtils.processGLSLShader(source: sourceCode)
            self.entryPoints = Self.getEntryPoints(from: self.sources)
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
        self.entryPoints = Self.getEntryPoints(from: self.sources)
        self.includeSearchPaths = includeSearchPaths
        self.language = lang
    }
    
    /// Create an empty shader sources
    public init() { }
    
    /// Set new shader source code for specific stage.
    public func setSource(_ source: String, for stage: ShaderStage) {
        self.sources[stage] = source
        self.entryPoints[stage] = (try? ShaderUtils.dropEntryPoint(from: source).0)
    }
    
    /// Get source code for specific stage.
    /// - Returns: Raw string code or nil if source code not saved for specific stage.
    public func getSource(for stage: ShaderStage) -> String? {
        return self.sources[stage]
    }
    
    /// Get entry point for specific code.
    public func getEntryPoint(for stage: ShaderStage) -> String {
        return self.entryPoints[stage] ?? "main"
    }
    
    /// Return collection of stages available in this shader source.
    public var stages: [ShaderStage] {
        return Array(self.sources.keys)
    }
    
    // MARK: - Resource
    
    public var resourceName: String = ""
    public var resourcePath: String = ""
    
    public static var resourceType: ResourceType = .material
    
    public init(asset decoder: AssetDecoder) throws {
        let fileURL = decoder.assetMeta.filePath
        self.fileURL = fileURL
        
        guard let data = FileSystem.current.readFile(at: fileURL) else {
            throw Error.failedToRead(fileURL.path)
        }
        
        let sourceCode = String(data: data, encoding: .utf8) ?? ""
        self.language = ShaderUtils.shaderLang(from: fileURL.pathExtension)
        self.includeSearchPaths = [.local(fileURL.deletingLastPathComponent())]
        
        switch language {
        case .glsl:
            let sources = try ShaderUtils.processGLSLShader(source: sourceCode)
            
            if
                let stageName = decoder.assetMeta.queryParams.first?.name,
                let stage = ShaderUtils.shaderStage(from: stageName)
            {
                guard let sourceForStage = sources[stage] else {
                    throw Error.message("Cannot find a source for stage \(stageName)")
                }
                
                self.sources = [stage : sourceForStage]
            } else {
                self.sources = sources
            }
        default:
            self.sources = [.max: sourceCode]
        }
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        fatalError()
    }
    
    private static func getEntryPoints(from sources: [ShaderStage : String]) -> [ShaderStage : String] {
        var entryPoints = [ShaderStage : String]()
        
        for (stage, source) in sources {
            entryPoints[stage] = try? ShaderUtils.dropEntryPoint(from: source).0
        }
        
        return entryPoints
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

// MARK: - UniqueHashable

extension ShaderSource: UniqueHashable {
    public static func == (lhs: ShaderSource, rhs: ShaderSource) -> Bool {
        lhs.includeSearchPaths == rhs.includeSearchPaths &&
        lhs.language == rhs.language &&
        lhs.sources == rhs.sources
    }
    
    public func hash(into hasher: inout FNVHasher) {
        for (stage, source) in self.sources {
            hasher.combine(stage.rawValue)
            hasher.combine(source)
        }
        
        for include in includeSearchPaths {
            switch include {
            case ._local(let url):
                hasher.combine(url.path)
            case ._module(let moduleName, let url):
                hasher.combine(moduleName)
                hasher.combine(url.path)
            }
        }
    }
}

extension ShaderSource: Hashable {
    public func hash(into hasher: inout Hasher) {
        for (stage, source) in self.sources {
            hasher.combine(stage.rawValue)
            hasher.combine(source)
        }
        
        for include in includeSearchPaths {
            switch include {
            case ._local(let url):
                hasher.combine(url.path)
            case ._module(let moduleName, let url):
                hasher.combine(moduleName)
                hasher.combine(url.path)
            }
        }
    }
}
