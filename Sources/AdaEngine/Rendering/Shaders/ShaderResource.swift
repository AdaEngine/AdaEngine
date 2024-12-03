//
//  ShaderResource.swift
//  AdaEngine
//
//  Created by v.prusakov on 3/19/23.
//

import SPIRV_Cross

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

/// Name space for shader resources.
public enum ShaderResource {
    
    public struct DescriptorSet: Codable {
        public var uniformsBuffers: [Int: ShaderBuffer] = [:]
        public var constantBuffers: [String: ShaderBuffer] = [:]
        public var sampledImages: [String: ImageSampler] = [:]
    }
    
    public enum ResourceAccess: Codable {
        case read
        case write
        case readWrite
    }
    
    /// Resource type that will be searching into shader.
    enum ResourceType: CaseIterable, Codable {
        case uniformBuffer
        case storageBuffer
        case pushConstantBuffer
        case image
        case sampledImage
        case storageImage
        case inputAttachment
        case sampler
    }
    
    /// Describe reflected uniform buffer information.
    public struct UniformBuffer: Codable {
        public let name: String
        public let binding: Int
        public let size: Int
        public let resourceAccess: ResourceAccess
    }
    
    /// Describe reflected sampler information.
    public struct Sampler: Codable {
        public let name: String
        public let binding: Int
    }
    
    /// Describe reflected texture information.
    public struct ImageSampler: Codable {
        let name: String
        let binding: Int
        let textureType: Texture.TextureType
        let descriptorSet: Int
        let arraySize: Int
        let shaderStage: ShaderStageFlags
        public let resourceAccess: ResourceAccess
    }
    
    /// Describe reflected shader buffer information. That shader buffer contains members (properties)
    public struct ShaderBuffer: Codable {
        public let name: String
        public let size: Int
        public let shaderStage: ShaderStageFlags
        public let binding: Int
        public let resourceAccess: ResourceAccess
        
        public let members: [String : ShaderBufferMember]
    }
    
    public struct ShaderBufferMember: Codable {
        let name: String
        let size: Int
        let binding: Int
        let type: ShaderValueType
        let offset: Int
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
        case .sampledImage:
            return SPVC_RESOURCE_TYPE_SAMPLED_IMAGE
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

/// Contains information about shader stages. For example, shader reflection data can have one or more stage flags for specific resource or buffer.
public struct ShaderStageFlags: OptionSet, Codable, Sendable {
    
    public let rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

extension ShaderStageFlags {
    init(shaderStage: ShaderStage) {
        switch shaderStage {
        case .vertex:
            self = .vertex
        case .fragment:
            self = .fragment
        case .compute:
            self = .compute
        case .tesselationControl:
            self = .tesselationControl
        case .tesselationEvaluation:
            self = .tesselationEvaluation
        case .max:
            self = .max
        }
    }
}

public extension ShaderStageFlags {
    static let vertex = ShaderStageFlags(rawValue: 1 << 0)
    static let fragment = ShaderStageFlags(rawValue: 1 << 1)
    static let compute = ShaderStageFlags(rawValue: 1 << 2)
    static let tesselationControl = ShaderStageFlags(rawValue: 1 << 3)
    static let tesselationEvaluation = ShaderStageFlags(rawValue: 1 << 4)
    
    /// Include all stages.
    static let max: ShaderStageFlags = [.vertex, .fragment, .compute, .tesselationControl, .tesselationEvaluation]
}

/// Contains relfection data of shader like uniforms buffers, textures and etc.
/// You can use this data to understand how to manipulate shader and how to build buffers for it.
public struct ShaderReflectionData: Codable {
    public var descriptorSets: [ShaderResource.DescriptorSet] = []
    
    /// Collection information about shader buffers, like: Uniform, push values and etc.
    public var shaderBuffers: [String: ShaderResource.ShaderBuffer] = [:]
    
    /// Collection information about shader resources, like: textures, samplers.
    public var resources: [String: ShaderResource.ImageSampler] = [:]
}

public extension ShaderReflectionData {
    // FIXME: We should merge descriptor sets
    
    /// Merge one ``ShaderReflectionData`` into another.
    mutating func merge(_ data: ShaderReflectionData) {
        self.shaderBuffers.merge(data.shaderBuffers) { _, new in return new }
        self.resources.merge(data.resources) { _, new in return new }
    }
}
