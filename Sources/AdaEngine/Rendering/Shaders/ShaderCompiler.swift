//
//  ShaderCompiler.swift
//  
//
//  Created by v.prusakov on 3/10/23.
//

import Foundation
import SPIRVCompiler
import SPIRV_Cross

struct SpirvBinary {
    let stage: ShaderStage
    let data: Data
    let language: ShaderLanguage
}

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
    
    public private(set) var includeSearchPaths: [String] = []
    private var shaderSource: ShaderSource
    
    public init(from fileUrl: URL) throws {
        self.shaderSource = try ShaderSource(from: fileUrl)
    }
    
    public init(shaderSource: ShaderSource) {
        self.shaderSource = shaderSource
    }
    
    public func addHeaderSearchPaths(_ paths: [String]) {
        self.includeSearchPaths.append(contentsOf: paths)
    }
    
    // MARK: - Private
    
    private func compile(for stage: ShaderStage) throws -> SpirvBinary {
        guard let source = self.shaderSource.getSource(for: stage) else {
            throw CompileError.failed("Sources  for stage \(stage.rawValue) not found")
        }
        
        return try self.compileCode(source, stage: stage)
    }
    
    private func compileCode(_ code: String, stage: ShaderStage) throws -> SpirvBinary {
        guard glslang_init_process() else {
            fatalError("Can't init glslang process")
        }

        defer {
            glslang_deinit_process()
        }

        var spirvBin = spirv_bin()
        var error: UnsafePointer<CChar>?
        
        let result = code.withCString { ptr in
            return compile_shader_glsl(
                ptr, /* source */
                stage.toShaderCompiler, /* stage */
                &spirvBin, /* output bin */
                &error /* output error */
            )
        }

        if let error {
            let message = String(cString: error, encoding: .utf8)!
            throw CompileError.glslError(message)
        }

        guard result == SHADERC_SUCCESS else {
            throw CompileError.glslError("Unknown error")
        }

//        let ptr = spirvBin.bytes.assumingMemoryBound(to: SpvId.self)
//        print(ptr.pointee)
        
        let data = Data(
            bytes: UnsafeRawPointer(spirvBin.bin.__dataUnsafe()),
            count: Int(spirvBin.bin.size()) * MemoryLayout<SpvId>.size
        )
        return SpirvBinary(stage: stage, data: data, language: self.shaderSource.language)
    }

    public func shader(stage: ShaderStage, to language: ShaderLanguage) -> String {
        do {
            let bin = try self.compileCode(self.shaderSource.getSource(for: stage)!, stage: stage)
            let compiler = try SpirvCompiler(spriv: bin)
            return compiler.compile(to: language)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    public func shader(_ data: Data, to language: ShaderLanguage) -> String {
        do {
            let bin = SpirvBinary(stage: .vertex, data: data, language: .glsl)
            let compiler = try SpirvCompiler(spriv: bin)
            return compiler.compile(to: language)
        } catch {
            fatalError(error.localizedDescription)
        }
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

extension ShaderLanguage {
    var spvcBackend: spvc_backend {
        switch self {
        case .msl:
            return SPVC_BACKEND_MSL
        case .hlsl:
            return SPVC_BACKEND_HLSL
        case .glsl:
            return SPVC_BACKEND_GLSL
        }
    }
}

final class SpirvCompiler {
    
    var context: spvc_context
    var ir: spvc_parsed_ir
    
    init(spriv: SpirvBinary) throws {
        var context: spvc_context!
        spvc_context_create(&context)
        
        var ir: spvc_parsed_ir!
        
        let result = spriv.data.withUnsafeBytes { spvPtr in
            let spv = spvPtr.bindMemory(to: SpvId.self)
            return spvc_context_parse_spirv(context, spv.baseAddress, spv.count, &ir)
        }
        
        print("[SpirvCompiler]", String(cString: spvc_context_get_last_error_string(context)))
        
        if result != SPVC_SUCCESS {
            fatalError("failed \(result.rawValue)")
        }
        
        self.ir = ir
        self.context = context
    }
    
    deinit {
        spvc_context_destroy(context)
    }
    
    func compile(to shaderLanguage: ShaderLanguage) -> String {
        var spvcCompiler: spvc_compiler?
        spvc_context_create_compiler(
            context,
            shaderLanguage.spvcBackend,
            ir,
            SPVC_CAPTURE_MODE_TAKE_OWNERSHIP,
            &spvcCompiler
        )
        
        print("[SpirvCompiler]", String(cString: spvc_context_get_last_error_string(context)))
        
        guard let spvcCompiler else {
            fatalError("can't create compiler")
        }
        
        var spvcCompilerOptions: spvc_compiler_options?
        if spvc_compiler_create_compiler_options(spvcCompiler, &spvcCompilerOptions) != SPVC_SUCCESS {
            return ""
        }
        
        let makeMSLVersion = { (major: UInt32, minor: UInt32, patch: UInt32) in
            return (major * 10000) + (minor * 100) + patch
        }
        spvc_compiler_options_set_uint(spvcCompilerOptions, SPVC_COMPILER_OPTION_MSL_VERSION, makeMSLVersion(2,1,0))
        spvc_compiler_options_set_bool(spvcCompilerOptions, SPVC_COMPILER_OPTION_MSL_ENABLE_POINT_SIZE_BUILTIN, spvc_bool(1))
        
        spvc_compiler_install_compiler_options(spvcCompiler, spvcCompilerOptions)
        
        var compilerOutputSourcePtr: UnsafePointer<CChar>?
        if spvc_compiler_compile(spvcCompiler, &compilerOutputSourcePtr) != SPVC_SUCCESS {
            print("[SpirvCompiler]", String(cString: spvc_context_get_last_error_string(context)))
            fatalError("failed to compile")
        }
        
        return String(cString: compilerOutputSourcePtr!)
    }
}
