//
//  SpirvCompiler.swift
//  
//
//  Created by v.prusakov on 3/13/23.
//

import SPIRV_Cross

struct SpirvShader {
    
    struct EntryPoint {
        let name: String
        let stage: ShaderStage
    }
    
    let source: String
    let language: ShaderLanguage
    let entryPoints: [EntryPoint]
}

/// Create High Level Shading Language from SPIR-V for specific shader language.
final class SpirvCompiler {
    
    static var deviceLang: ShaderLanguage {
#if METAL
        return .msl
#else
        return .glsl
#endif
    }
    
    var context: spvc_context
    var spvcCompiler: spvc_compiler
    var ir: spvc_parsed_ir
    
    struct Error: LocalizedError {
        let message: String
        let file: StaticString
        let function: StaticString
        
        init(_ message: String, file: StaticString = #file, function: StaticString = #function) {
            self.message = message
            self.file = file
            self.function = function
        }
        
        var errorDescription: String? {
            return "[SpirvCompiler] \(file):\(function)" + message
        }
    }
    
    init(spriv: Data) throws {
        var context: spvc_context!
        spvc_context_create(&context)
        
        var ir: spvc_parsed_ir!
        
        let result = spriv.withUnsafeBytes { spvPtr in
            let spv = spvPtr.bindMemory(to: SpvId.self)
            return spvc_context_parse_spirv(context, spv.baseAddress, spv.count, &ir)
        }
        
        if result != SPVC_SUCCESS {
            throw Error(String(cString: spvc_context_get_last_error_string(context)))
        }
        
        self.ir = ir
        self.context = context
        
        var spvcCompiler: spvc_compiler?
        spvc_context_create_compiler(
            context,
            Self.deviceLang.spvcBackend,
            ir,
            SPVC_CAPTURE_MODE_TAKE_OWNERSHIP,
            &spvcCompiler
        )
        
        guard let spvcCompiler else {
            throw Error(String(cString: spvc_context_get_last_error_string(context)))
        }
        
        self.spvcCompiler = spvcCompiler
    }
    
    deinit {
        spvc_context_destroy(context)
    }
    
    /// Compile shader to device specific language
    func compile() throws -> SpirvShader {
        var spvcCompilerOptions: spvc_compiler_options?
        if spvc_compiler_create_compiler_options(spvcCompiler, &spvcCompilerOptions) != SPVC_SUCCESS {
            throw Error(String(cString: spvc_context_get_last_error_string(context)))
        }
        
        Self.makeCompileOptions(spvcCompilerOptions)
        
        spvc_compiler_install_compiler_options(spvcCompiler, spvcCompilerOptions)
        
        var compilerOutputSourcePtr: UnsafePointer<CChar>?
        if spvc_compiler_compile(spvcCompiler, &compilerOutputSourcePtr) != SPVC_SUCCESS {
            throw Error(String(cString: spvc_context_get_last_error_string(context)))
        }
        
        let source = String(cString: compilerOutputSourcePtr!)
        
        var numberOfEntryPoints: Int = 0
        var spvcEntryPoints: UnsafePointer<spvc_entry_point>?
        spvc_compiler_get_entry_points(spvcCompiler, &spvcEntryPoints, &numberOfEntryPoints)
        
        var entryPoints: [SpirvShader.EntryPoint] = []
        
        for index in 0..<numberOfEntryPoints {
            let entryPoint = spvcEntryPoints![index]
            
            let name = spvc_compiler_get_cleansed_entry_point_name(
                spvcCompiler, /* compiler */
                entryPoint.name, /* entry point name */
                entryPoint.execution_model /* execution model */
            )!
            
            entryPoints.append(
                SpirvShader.EntryPoint(
                    name: String(cString: name), // FIXME: Looks like a bug
                    stage: ShaderStage(from: entryPoint.execution_model)
                )
            )
        }
        
        return SpirvShader(
            source: source,
            language: Self.deviceLang,
            entryPoints: entryPoints
        )
    }
    
    func setEntryPoint(_ entryPointName: String) {
        var numberOfEntryPoints: Int = 0
        var spvcEntryPoints: UnsafePointer<spvc_entry_point>?
        spvc_compiler_get_entry_points(spvcCompiler, &spvcEntryPoints, &numberOfEntryPoints)

        for index in 0..<numberOfEntryPoints {
            let entryPoint = spvcEntryPoints![index]

            let result = entryPointName.withCString { entryPtr in
                spvc_compiler_rename_entry_point(
                    spvcCompiler, /* compiler */
                    entryPoint.name, /* old_name */
                    entryPtr, /* new_name */
                    entryPoint.execution_model /* excution_model */
                )
            }

            if result != SPVC_SUCCESS {
                assertionFailure("Can't set entry point \(entryPointName) for \(ShaderStage(from: entryPoint.execution_model))")
            }
        }
    }
    
    func reflect() {
        
    }
}

extension SpirvCompiler {
    static func makeCompileOptions(_ options: spvc_compiler_options?) {
        #if METAL
        let version = { (major: UInt32, minor: UInt32, patch: UInt32) in
            return (major * 10000) + (minor * 100) + patch
        }
        spvc_compiler_options_set_uint(options, SPVC_COMPILER_OPTION_MSL_VERSION, version(2, 1, 0))
        spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_MSL_ENABLE_POINT_SIZE_BUILTIN, 1)
        
        let platform = Application.shared.platform == .macOS ? SPVC_MSL_PLATFORM_MACOS : SPVC_MSL_PLATFORM_IOS
        spvc_compiler_options_set_uint(options, SPVC_COMPILER_OPTION_MSL_PLATFORM, platform.rawValue)
        spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_MSL_ENABLE_DECORATION_BINDING, 1)
        #endif
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
        default:
            return SPVC_BACKEND_NONE
        }
    }
}

extension ShaderStage {
    init(from executionModel: SpvExecutionModel) {
        switch executionModel {
        case SpvExecutionModelFragment:
            self = .fragment
        case SpvExecutionModelVertex:
            self = .vertex
        case SpvExecutionModelGLCompute:
            self = .compute
        case SpvExecutionModelTessellationControl:
            self = .tesselationControl
        case SpvExecutionModelTessellationEvaluation:
            self = .tesselationEvaluation
        default:
            self = .max
        }
    }
}
