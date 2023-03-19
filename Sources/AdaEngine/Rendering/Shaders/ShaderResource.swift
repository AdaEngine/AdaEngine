//
//  ShaderResource.swift
//  
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

struct ShaderReflectionData: Codable {
    var descriptorSets: [ShaderResource.DescriptorSet] = []
    var shaderBuffers: [String: ShaderResource.ShaderBuffer] = [:]
    var resources: [String: ShaderResource.ImageSampler] = [:]
}

public enum ShaderResource {
    
    struct DescriptorSet: Codable {
        var uniformsBuffers: [Int: ShaderBuffer] = [:]
        var constantBuffers: [String: ShaderBuffer] = [:]
        var sampledImages: [String: ImageSampler] = [:]
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
    
    public struct ImageSampler: Codable {
        let name: String
        let binding: Int
        let descriptorSet: Int
        let arraySize: Int
        let shaderStage: ShaderStageFlags
    }
    
    public struct ShaderBuffer: Codable {
        public let name: String
        public let size: Int
        public let shaderStage: ShaderStageFlags
        public let binding: Int
        
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

public struct ShaderStageFlags: OptionSet, Codable {
    
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
    
    static let max: ShaderStageFlags = [.vertex, .fragment, .compute, .tesselationControl, .tesselationEvaluation]
}
