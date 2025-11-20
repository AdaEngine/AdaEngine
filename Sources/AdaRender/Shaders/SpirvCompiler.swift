//
//  SpirvCompiler.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/13/23.
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SPIRV_Cross
import Logging

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

    let deviceLang: ShaderLanguage
    private let stage: ShaderStage

    var context: spvc_context
    var spvcCompiler: spvc_compiler
    var ir: spvc_parsed_ir
    
    let loggerShader = Logger(label: "SpirvCompiler")

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

    init(spriv: Data, stage: ShaderStage, deviceLang: ShaderLanguage) throws {
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
        
        self.deviceLang = deviceLang
        var spvcCompiler: spvc_compiler?
        spvc_context_create_compiler(
            context,
            deviceLang.spvcBackend,
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
            let errorMessage = String(cString: spvc_context_get_last_error_string(context))
            loggerShader.critical("⚠️ SPIRV-Cross compiler options creation failed: \(errorMessage)")
            throw Error(errorMessage)
        }

        Self.makeCompileOptions(spvcCompilerOptions, deviceLang: deviceLang)

        spvc_compiler_install_compiler_options(spvcCompiler, spvcCompilerOptions)

        var compilerOutputSourcePtr: UnsafePointer<CChar>?
        let result = spvc_compiler_compile(spvcCompiler, &compilerOutputSourcePtr)
        if result != SPVC_SUCCESS {
            let errorMessage = String(cString: spvc_context_get_last_error_string(context))
            loggerShader.critical("⚠️ SPIRV-Cross compilation failed: \(errorMessage)")
            
            // Print detailed diagnostic info
            loggerShader.critical("🔍 Target language: \(deviceLang)")
            loggerShader.critical("🔍 Shader stage: \(stage)")
            
            // If we have entry points, print them
            var numberOfEntryPoints: Int = 0
            var spvcEntryPoints: UnsafePointer<spvc_entry_point>?
            spvc_compiler_get_entry_points(spvcCompiler, &spvcEntryPoints, &numberOfEntryPoints)
            
            if numberOfEntryPoints > 0 {
                loggerShader.critical("🔍 Entry points:")
                for index in 0..<numberOfEntryPoints {
                    let entryPoint = spvcEntryPoints![index]
                    loggerShader.critical("  - \(String(cString: entryPoint.name)) (execution model: \(entryPoint.execution_model))")
                }
            } else {
                loggerShader.critical("⚠️ No entry points found in shader")
            }
            
            throw Error(errorMessage)
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
                    name: String(cString: name),
                    stage: ShaderStage(from: entryPoint.execution_model)
                )
            )
        }

        return SpirvShader(
            source: source,
            language: self.deviceLang,
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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func reflection() -> ShaderReflectionData {
        var shaderResources: spvc_resources!
        spvc_compiler_create_shader_resources(self.spvcCompiler, &shaderResources)

        var reflectionData = ShaderReflectionData()

        for resourceType in ShaderResource.ResourceType.allCases {
            var reflectedResources : UnsafePointer<spvc_reflected_resource>!
            var reflectedResourceCount = 0

            spvc_resources_get_resource_list_for_type(shaderResources, resourceType.spvcResourceType, &reflectedResources, &reflectedResourceCount)

            for index in 0..<reflectedResourceCount {
                let resource = reflectedResources[index]
                let resourceName = String(cString: resource.name)

                // Skip internal uniforms
                if resourceName.hasPrefix("AE_") {
                    continue
                }

                let type = spvc_compiler_get_type_handle(self.spvcCompiler, resource.base_type_id)
                var size: Int = 0
                spvc_compiler_get_declared_struct_size(self.spvcCompiler, type, &size)

                let binding = spvc_compiler_get_decoration(self.spvcCompiler, resource.id, SpvDecorationBinding)
                let descriptorSetIndex = spvc_compiler_get_decoration(self.spvcCompiler, resource.id, SpvDecorationDescriptorSet)

                if descriptorSetIndex >= reflectionData.descriptorSets.count {
                    reflectionData.descriptorSets.append(ShaderResource.DescriptorSet())
                }

                var descriptorSet = reflectionData.descriptorSets[Int(descriptorSetIndex)]

                switch resourceType {
                case .uniformBuffer, .pushConstantBuffer:
                    var members = [String: ShaderResource.ShaderBufferMember]()

                    let memberTypesCount = spvc_type_get_num_member_types(type)

                    for index in 0 ..< memberTypesCount {
                        let memberType = spvc_type_get_member_type(type, index)
                        let memberName = String(cString: spvc_compiler_get_member_name(self.spvcCompiler, resource.base_type_id, index))
                        var memberSize: Int = 0
                        spvc_compiler_get_declared_struct_member_size(self.spvcCompiler, type, index, &memberSize)

                        var memberOffset: UInt32 = 0
                        spvc_compiler_type_struct_member_offset(self.spvcCompiler, type, index, &memberOffset)

                        members[memberName] = ShaderResource.ShaderBufferMember(
                            name: memberName,
                            size: memberSize,
                            binding: Int(binding),
                            type: ShaderValueType(typeId: memberType, compiler: self.spvcCompiler) ?? .none,
                            offset: Int(memberOffset)
                        )
                    }

                    let buffer = ShaderResource.ShaderBuffer(
                        name: resourceName,
                        size: size,
                        shaderStage: ShaderStageFlags(shaderStage: self.stage),
                        binding: Int(binding),
                        resourceAccess: .readWrite,
                        members: members
                    )

                    descriptorSet.uniformsBuffers[Int(binding)] = buffer
                    reflectionData.shaderBuffers[resourceName] = buffer
                case .image, .sampler, .inputAttachment, .storageImage, .sampledImage:
                    let access = spvc_type_get_image_access_qualifier(type)
                    let isArray = spvc_type_get_image_arrayed(type) == 1
                    let isMultisampled = spvc_type_get_image_multisampled(type) == 1
                    let dimension = spvc_type_get_image_dimension(type)
                    let arraySize = spvc_type_get_array_dimension(type, 0)

                    let resourceAccess: ShaderResource.ResourceAccess

                    if resourceType == .storageImage || access == SpvAccessQualifierReadOnly {
                        resourceAccess = .read
                    } else if access == SpvAccessQualifierWriteOnly {
                        resourceAccess = .write
                    } else {
                        resourceAccess = .readWrite
                    }

                    var textureType: Texture.TextureType = .texture2D

                    switch dimension {
                    case SpvDim1D:
                        textureType = isArray ? .texture1DArray : .texture1D
                    case SpvDim2D:
                        if isMultisampled {
                            textureType = isArray ? .texture2DMultisampleArray : .texture2DMultisample
                        } else {
                            textureType = isArray ? .texture2DArray : .texture2D
                        }
                    case SpvDim3D:
                        textureType = .texture3D
                    case SpvDimCube:
                        textureType = .textureCube
                    case SpvDimBuffer:
                        textureType = .textureBuffer
                    default:
                        break
                    }

                    let image = ShaderResource.ImageSampler(
                        name: resourceName,
                        binding: Int(binding),
                        textureType: textureType,
                        descriptorSet: Int(descriptorSetIndex),
                        arraySize: Int(arraySize),
                        shaderStage: ShaderStageFlags(shaderStage: self.stage),
                        resourceAccess: resourceAccess
                    )

                    reflectionData.resources[resourceName] = image
                    descriptorSet.sampledImages[Int(binding)] = image
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
    static func makeCompileOptions(_ options: spvc_compiler_options?, deviceLang: ShaderLanguage) {
        let version = { (major: UInt32, minor: UInt32, patch: UInt32) in
            return (major * 10000) + (minor * 100) + patch
        }
        
        if deviceLang == .msl {
            spvc_compiler_options_set_uint(options, SPVC_COMPILER_OPTION_MSL_VERSION, version(2, 1, 0))
            spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_MSL_ENABLE_POINT_SIZE_BUILTIN, 1)

#if os(macOS)
            let platform = SPVC_MSL_PLATFORM_MACOS
#else
            let platform = SPVC_MSL_PLATFORM_IOS
#endif

            spvc_compiler_options_set_uint(options, SPVC_COMPILER_OPTION_MSL_PLATFORM, platform.rawValue)
            spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_MSL_ENABLE_DECORATION_BINDING, 1)
        }

        if deviceLang == .glsl {
            // Set GLSL version to 4.10, matching our OpenGL context
            spvc_compiler_options_set_uint(options, SPVC_COMPILER_OPTION_GLSL_VERSION, 410)
        
            // Enable GLSL specific options for better compatibility
            spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_GLSL_SEPARATE_SHADER_OBJECTS, 1)
            spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_GLSL_ENABLE_420PACK_EXTENSION, 1)
            spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_GLSL_ES, 0) // Use desktop GLSL, not GLSL ES
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
        default:
            return SPVC_BACKEND_NONE
        }
    }
}
