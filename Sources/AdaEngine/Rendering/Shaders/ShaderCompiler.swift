//
//  ShaderCompiler.swift
//  
//
//  Created by v.prusakov on 3/10/23.
//

import Foundation
import SPIRVCompiler
import SPIRV_Cross

// TODO: Should we invert y-axis for vertex shader?

struct SpirvBinary {
    let stage: ShaderStage
    let data: Data
    let language: ShaderLanguage
    let entryPoint: String
}

/// ShaderCompiler is an entity to compile GLSL code to Shader objects (with SPIR-V binary).
public final class ShaderCompiler {
    
    enum CompileError: LocalizedError {
        case fileReadingFailed(String)
        case glslError(String)
        case failed(String)
        
        var errorDescription: String? {
            switch self {
            case .fileReadingFailed(let path):
                return "[ShaderCompiler] Failed to read file at path \(path)."
            case .glslError(let msg):
                return "[ShaderCompiler] GLSLang compile failed with error: \(msg)"
            case .failed(let msg):
                return "[ShaderCompiler] Failed: \(msg)."
            }
        }
    }
    
    // Collection of include search paths available for your shader source.
    public private(set) var includeSearchPaths: [ShaderSource.IncludeSearchPath] = [
        .module(
            name: "AdaEngine",
            modulePath: Bundle.current.resourceURL!.appendingPathComponent("Shaders/Vulkan/Public")
        )
    ]
    
    private var shaderSource: ShaderSource
    
    public init(from fileUrl: URL) throws {
        self.shaderSource = try ShaderSource(from: fileUrl)
        self.includeSearchPaths.append(contentsOf: self.shaderSource.includeSearchPaths)
    }
    
    public init(shaderSource: ShaderSource) {
        self.shaderSource = shaderSource
        self.includeSearchPaths.append(contentsOf: shaderSource.includeSearchPaths)
    }
    
    public func addHeaderSearchPaths(_ paths: [ShaderSource.IncludeSearchPath]) {
        self.includeSearchPaths.append(contentsOf: paths)
    }
    
    public func setShader(_ source: ShaderSource, for stage: ShaderStage) {
        self.shaderSource.setSource(source.getSource(for: stage)!, for: stage)
    }
    
    /// Compile all shader sources to shader module.
    public func compileShaderModule() throws -> ShaderModule {
        var shaders: [ShaderStage: Shader] = [:]
        
        var reflectionData = ShaderReflectionData()
        
        for stage in self.shaderSource.stages {
            let shader = try self.compileShader(for: stage)
            shaders[stage] = shader
            // Merge
            reflectionData.shaderBuffers.merge(shader.reflectionData.shaderBuffers) { _, new in return new }
        }
        
        return ShaderModule(shaders: shaders, reflectionData: reflectionData)
    }
    
    /// Compile shader by specific shader stage.
    /// - Returns: Compiled Shader object.
    /// - Throws: Error if something went wrong on compilation to SPIR-V.
    public func compileShader(for stage: ShaderStage) throws -> Shader {
        let binary = try self.compileSpirvBin(for: stage, ignoreCache: false)
        let shader = try Shader.make(from: binary, compiler: self)
        
        if let reflection = ShaderCache.getReflection(for: self.shaderSource, stage: stage) {
            shader.reflectionData = reflection
        } else {
            let data = shader.reflect()
            shader.reflectionData = data
            try ShaderCache.saveReflection(data, for: self.shaderSource, stage: stage)
        }
        
        return shader
    }
    
    // MARK: - Private
    
    // Get SPIRV from cache or compile new if something change in file.
    internal func compileSpirvBin(for stage: ShaderStage, ignoreCache: Bool = false) throws -> SpirvBinary {
        if !ShaderCache.hasChanges(for: self.shaderSource).contains(stage), !ignoreCache {
            let entryPoint = self.shaderSource.getEntryPoint(for: stage)
            if let binary = ShaderCache.getCachedShader(for: self.shaderSource, stage: stage, entryPoint: entryPoint) {
                return binary
            }
        }
        
        guard let code = self.shaderSource.getSource(for: stage) else {
            throw CompileError.failed("Sources for stage `\(stage.rawValue)` not found")
        }
        
        let processedCode = try ShaderIncluder.processIncludes(in: code, includeSearchPath: self.includeSearchPaths)
        let (entryPoint, ppCode) = try ShaderUtils.dropEntryPoint(from: processedCode)
        let spirv = try self.compileCode(ppCode, entryPoint: entryPoint, stage: stage)
        try? ShaderCache.save(spirv, source: self.shaderSource, stage: stage)
        
        return spirv
    }
    
    internal func compileCode(_ code: String, entryPoint: String, stage: ShaderStage) throws -> SpirvBinary {
        guard glslang_init_process() else {
            throw CompileError.glslError("Can't create glslang process.")
        }

        defer {
            glslang_deinit_process()
        }
        
        var error: UnsafePointer<CChar>?
        
        let binary = entryPoint.withCString { entryNamePtr in
            let options = spirv_options(entryPointName: entryNamePtr)
            
            return code.withCString { sourcePtr in
                compile_shader_glsl(
                    sourcePtr, /* source */
                    stage.toShaderCompiler, /* stage */
                    options, /* options */
                    &error /* output error */
                )
            }
        }
        
        if let error {
            let message = String(cString: error, encoding: .utf8)!
            throw CompileError.glslError(message)
        }
        
        let data = Data(bytes: binary.bytes, count: binary.length)
        binary.bytes.deallocate()
        
        return SpirvBinary(
            stage: stage,
            data: data,
            language: self.shaderSource.language,
            entryPoint: entryPoint
        )
    }
}

extension ShaderStage {
    var toShaderCompiler: shaderc_stage {
        switch self {
        case .compute:
            return SHADER_STAGE_COMPUTE
        case .fragment:
            return SHADER_STAGE_FRAGMENT
        case .vertex:
            return SHADER_STAGE_VERTEX
        case .tesselationControl:
            return SHADER_STAGE_TESSELATION_CONTROL
        case .tesselationEvaluation:
            return SHADER_STAGE_TESSELATION_EVALUATION
        case .max:
            return SHADER_STAGE_MAX
        }
    }
}
