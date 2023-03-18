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
    
    private let stage: ShaderStage
    
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
    
    init(spriv: Data, stage: ShaderStage) throws {
        self.stage = stage
        
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
    
    // Rename default entry point.
    func renameEntryPoint(_ entryPointName: String) {
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
    
    func reflection() -> ShaderReflectionData {
        var shaderResources : spvc_resources?
        
        var activeSet: spvc_set!
        spvc_compiler_get_active_interface_variables(self.spvcCompiler, &activeSet)
        
        var activeResources: spvc_resources!
        spvc_compiler_create_shader_resources_for_active_variables(self.spvcCompiler, &activeResources, activeSet)
        spvc_compiler_create_shader_resources(self.spvcCompiler, &shaderResources)
        
        var reflectionData = ShaderReflectionData()
        
        for resourceType in ShaderResource.ResourceType.allCases {
            var reflectedResources : UnsafePointer<spvc_reflected_resource>!
            var reflectedResourceCount = 0
            
            spvc_resources_get_resource_list_for_type(activeResources, resourceType.spvcResourceType, &reflectedResources, &reflectedResourceCount)
            
            for index in 0..<reflectedResourceCount {
                let resource = reflectedResources[index]
                
                let type = spvc_compiler_get_type_handle(self.spvcCompiler, resource.base_type_id)
                var size: Int = 0
                spvc_compiler_get_declared_struct_size(self.spvcCompiler, type, &size)
                
                let binding = spvc_compiler_get_decoration(self.spvcCompiler, resource.id, SpvDecorationBinding)
                let descriptorSetIndex = spvc_compiler_get_decoration(self.spvcCompiler, resource.id, SpvDecorationDescriptorSet)
                var descriptorSet = reflectionData.descriptorSets[Int(descriptorSetIndex)] ?? ShaderResource.DescriptorSet()
                
                switch resourceType {
                case .uniformBuffer, .pushConstantBuffer:
                    descriptorSet.uniformsBuffers[Int(binding)] = ShaderResource.UniformBuffer(
                        name: String(cString: resource.name),
                        binding: Int(binding),
                        size: size
                    )
                case .pushConstantBuffer:
//                    descriptorSet.constantBuffers[Int(binding), default: []].append(
//                        ShaderResource.UniformBuffer(
//                            name: String(cString: resource.name),
//                            binding: Int(binding),
//                            size: size
//                        )
//                    )
                    break
                default:
                    continue
                }
                
                reflectionData.descriptorSets[Int(descriptorSetIndex)] = descriptorSet
            }
        }
        
        return reflectionData
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

struct ShaderReflectionData: Codable {
    var descriptorSets: [Int: ShaderResource.DescriptorSet] = [:]
}

public enum ShaderResource {
    
    struct DescriptorSet: Codable {
        var uniformsBuffers: [Int: UniformBuffer] = [:]
        var constantBuffers: [String: ShaderBuffer] = [:]
    }
    
    enum ResourceType: CaseIterable, Codable {
        case uniformBuffer
        case storageBuffer
        case pushConstantBuffer
        case image
        case storageImage
        case inputAttachment
        case sampler
    }
    
    public struct UniformBuffer: Codable {
        public let name: String
        public let binding: Int
        public let size: Int
    }
    
    public struct Sampler: Codable {
        public let name: String
        public let binding: Int
    }
    
    public struct ShaderBuffer: Codable {
        public let name: String
        public let size: String
    }
}

extension ShaderResource.ResourceType {
    
    var spvcResourceType: spvc_resource_type {
        switch self {
        case .uniformBuffer:
            return SPVC_RESOURCE_TYPE_UNIFORM_BUFFER
        case .storageBuffer:
            return SPVC_RESOURCE_TYPE_STORAGE_BUFFER
        case .sampler:
            return SPVC_RESOURCE_TYPE_SEPARATE_SAMPLERS
        case .storageImage:
            return SPVC_RESOURCE_TYPE_STORAGE_IMAGE
        case .image:
            return SPVC_RESOURCE_TYPE_SEPARATE_IMAGE
        case .pushConstantBuffer:
            return SPVC_RESOURCE_TYPE_PUSH_CONSTANT
        case .inputAttachment:
            return SPVC_RESOURCE_TYPE_SUBPASS_INPUT
        }
    }
}

extension ShaderValueType {
    // swiftlint:disable:next cyclomatic_complexity
    init?(typeId: spvc_type_id, compiler: spvc_compiler) {
        let type = spvc_compiler_get_type_handle(compiler, typeId)
        let baseType = spvc_type_get_basetype(type)
        switch baseType {
        case SPVC_BASETYPE_BOOLEAN:
            self = .bool
        case SPVC_BASETYPE_FP16:
            self = .half
        case SPVC_BASETYPE_UINT8:
            self = .char
        case SPVC_BASETYPE_FP32:
            let vectorCount = spvc_type_get_vector_size(type)
            let columnCount = spvc_type_get_columns(type)
            
            if columnCount == 3 {
                self = .mat3
                return
            }
            
            if columnCount == 4 {
                self = .mat4
                return
            }
            
            switch vectorCount {
            case 1:
                self = .float
            case 2:
                self = .vec2
            case 3:
                self = .vec3
            case 4:
                self = .vec4
            default:
                return nil
            }
        case SPVC_BASETYPE_INT16:
            self = .short
        case SPVC_BASETYPE_UINT64:
            self = .uint
        case SPVC_BASETYPE_INT64:
            self = .int
        default:
            return nil
        }
    }
}
