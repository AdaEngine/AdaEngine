//
//  Mesh.swift
//  
//
//  Created by v.prusakov on 11/1/21.
//

import MetalKit
import ModelIO

protocol Resource {
    
}

public final class Mesh: Resource {
    
    public var verticies: [Vector3]
    public var indicies: [Int]
    
    var submeshes: [Mesh] = []
    
    /// Include submeshes vertex count
    public var vertexCount: Int {
        return self.submeshes
            .map(\.vertexCount)
            .reduce(self.verticies.count, +)
    }
    
    var vertexDescriptor: MeshVertexDescriptor
    
    public init(verticies: [Vector3], indicies: [Int], descriptor: MeshVertexDescriptor, submeshes: [Mesh]) {
        self.verticies = verticies
        self.indicies = indicies
        self.vertexDescriptor = descriptor
    }
    
}

public extension Mesh {
    static func loadMesh(from url: URL) -> Mesh {
        let asset = MDLAsset(url: url)
        
        fatalError()
    }
}

public class MeshVertexDescriptor {
    
    var attributes: [Attribute]
    var layouts: [Layout]
    
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
    
    public init(attributes: [Attribute] = [], layouts: [Layout] = []) {
        self.attributes = attributes
        self.layouts = layouts
    }
    
}

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
        
        self.init(attributes: attributes, layouts: layouts)
    }
    
    func makeVertexDescriptor() throws -> MTLVertexDescriptor? {
        let descriptor = MDLVertexDescriptor()
        descriptor.attributes = NSMutableArray(array: self.attributes.map(makeMDLVertexAttribute))
        descriptor.layouts = NSMutableArray(array: self.layouts.map { MDLVertexBufferLayout(stride: $0.stride) })
        
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
