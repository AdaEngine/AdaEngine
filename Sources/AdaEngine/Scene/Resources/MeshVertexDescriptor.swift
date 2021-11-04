//
//  MeshVertexDescriptor.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public struct VertexDesciptorAttributesArray {
    
    internal var buffer: [MeshVertexDescriptor.Attribute] = []
    
    subscript(index: Int) -> MeshVertexDescriptor.Attribute {
        mutating get {
            if self.buffer.indices.contains(index) {
                return self.buffer[index]
            }
            
            let attribute = MeshVertexDescriptor.Attribute(offset: 0, bufferIndex: 0, format: .invalid)
            self.buffer.insert(attribute, at: index)
            return attribute
        }
        
        set {
            self.buffer[index] = newValue
        }
    }
}

public struct VertexDesciptorLayoutsArray {
    
    internal private(set) var buffer: [MeshVertexDescriptor.Layout] = []
    
    subscript(index: Int) -> MeshVertexDescriptor.Layout {
        mutating get {
            if self.buffer.indices.contains(index) {
                return self.buffer[index]
            }
            
            let attribute = MeshVertexDescriptor.Layout(stride: 0)
            self.buffer.insert(attribute, at: index)
            return attribute
        }
        
        set {
            self.buffer[index] = newValue
        }
    }
}

public class MeshVertexDescriptor {
    
    public var attributes: VertexDesciptorAttributesArray
    public var layouts: VertexDesciptorLayoutsArray
    
    enum VertexFormat: UInt {
        case invalid
        
        case uint
        
        case vector4
        case vector3
        case vector2
        
        case matrix4x4
        case matrix3x3
        case matrix2x2
    }
    
    public struct Attribute {
        var offset: Int
        var bufferIndex: Int
        var format: VertexFormat
    }
    
    public struct Layout {
        var stride: Int
    }
    
    public init() {
        self.attributes = VertexDesciptorAttributesArray()
        self.layouts = VertexDesciptorLayoutsArray()
    }
    
    init(attributes: VertexDesciptorAttributesArray, layouts: VertexDesciptorLayoutsArray) {
        self.attributes = attributes
        self.layouts = layouts
    }
    
}

public extension MeshVertexDescriptor {
    static let defaultVertexDescriptor: MeshVertexDescriptor = {
        let descriptor = MeshVertexDescriptor()
        
        var offset = 0
        
        descriptor.attributes[0].bufferIndex = 0
        descriptor.attributes[0].format = .vector4
        descriptor.attributes[0].offset = offset
        
        offset += MemoryLayout<Vector3>.stride
        
        descriptor.layouts[0].stride = offset
        
        return descriptor
    }()
}

#if canImport(MetalKit) && canImport(ModelIO)

import MetalKit
import ModelIO

public extension MeshVertexDescriptor {
    convenience init(mdlVertexDescriptor: MDLVertexDescriptor) {
        
        let attributes: [Attribute] = mdlVertexDescriptor.attributes.map {
            let attr = ($0 as! MDLVertexAttribute)
            return Attribute(
                offset: attr.offset,
                bufferIndex: attr.bufferIndex,
                format: VertexFormat(vertexFormat: attr.format))
        }
        
        let layouts: [Layout] = mdlVertexDescriptor.layouts.map {
            let layout = ($0 as! MDLVertexBufferLayout)
            return Layout(stride: layout.stride)
        }
        
        self.init()
        
        self.attributes = VertexDesciptorAttributesArray(buffer: attributes)
        self.layouts = VertexDesciptorLayoutsArray(buffer: layouts)
    }
    
    func makeVertexDescriptor() throws -> MTLVertexDescriptor? {
        let descriptor = MDLVertexDescriptor()
        descriptor.attributes = NSMutableArray(array: self.attributes.buffer.map(makeMDLVertexAttribute))
        descriptor.layouts = NSMutableArray(array: self.layouts.buffer.map { MDLVertexBufferLayout(stride: $0.stride) })
        
        return try MTKMetalVertexDescriptorFromModelIOWithError(descriptor)
    }
    
    private func makeMDLVertexAttribute(from attribute: Attribute) -> MDLVertexAttribute {
        let mdlAttribute = MDLVertexAttribute()
        mdlAttribute.bufferIndex = attribute.bufferIndex
        mdlAttribute.offset = attribute.offset
        mdlAttribute.format = attribute.format.mdlVertexFormat
        return mdlAttribute
    }
}

extension MeshVertexDescriptor.VertexFormat {
    var mdlVertexFormat: MDLVertexFormat {
        switch self {
        case .uint: return .uInt
        case .vector4: return .float4
        case .vector3: return .float3
        case .vector2: return .float2
        case .matrix4x4: return .half4
        case .matrix3x3: return .half3
        case .matrix2x2: return .half2
        case .invalid: return .invalid
        }
    }
    
    init(vertexFormat: MDLVertexFormat) {
        switch vertexFormat {
        case .uInt: self = .uint
        case .float4: self = .vector4
        case .float3: self = .vector3
        case .float2: self = .vector2
        case .half4: self = .matrix4x4
        case .half3: self = .matrix3x3
        case .half2: self = .matrix2x2
        default:
            self = .invalid
        }
    }
}

#endif
