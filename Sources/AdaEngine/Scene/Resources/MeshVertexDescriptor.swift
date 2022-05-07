//
//  MeshVertexDescriptor.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public struct VertexDesciptorAttributesArray: Sequence, Codable {
    
    public typealias Element = MeshVertexDescriptor.Attribute
    public typealias Iterator = Array<MeshVertexDescriptor.Attribute>.Iterator
    
    var count: Int { self.buffer.count }
    
    internal var buffer: [MeshVertexDescriptor.Attribute] = []
    
    subscript(index: Int) -> MeshVertexDescriptor.Attribute {
        mutating get {
            if self.buffer.indices.contains(index) {
                return self.buffer[index]
            }
            
            let attribute = MeshVertexDescriptor.Attribute(name: "", offset: 0, bufferIndex: 0, format: .invalid)
            self.buffer.insert(attribute, at: index)
            return attribute
        }
        
        set {
            self.buffer[index] = newValue
        }
    }
    
    public func makeIterator() -> Iterator {
        return buffer.makeIterator()
    }
}

public struct VertexDesciptorLayoutsArray: Sequence, Codable {
    
    public typealias Element = MeshVertexDescriptor.Layout
    public typealias Iterator = Array<MeshVertexDescriptor.Layout>.Iterator
    
    internal private(set) var buffer: [MeshVertexDescriptor.Layout] = []
    
    var count: Int { self.buffer.count }
    
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
    
    public func makeIterator() -> Iterator {
        return buffer.makeIterator()
    }
}

public struct MeshVertexDescriptor: Codable {
    
    public var attributes: VertexDesciptorAttributesArray
    public var layouts: VertexDesciptorLayoutsArray
    
    public enum VertexFormat: UInt, Codable {
        case invalid
        
        case uint
        
        case vector4
        case vector3
        case vector2
        
        case matrix4x4
        case matrix3x3
        case matrix2x2
    }
    
    public struct Attribute: CustomStringConvertible, Codable {
        public var name: String
        public var offset: Int
        public var bufferIndex: Int
        public var format: VertexFormat
        
        public var description: String {
            return "Attribute: name=\(name) offset=\(offset) bufferIndex=\(bufferIndex) format=\(format)"
        }
    }
    
    public struct Layout: CustomStringConvertible, Codable {
        public var stride: Int
        
        public var description: String {
            return "Layout: stride=\(stride)"
        }
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

extension MeshVertexDescriptor: CustomStringConvertible {
    public var description: String {
        
        let attributesDesc = self.attributes.enumerated().reduce("", { result, value in
            let shouldInsertColumn = value.offset < self.attributes.count - 1
            let newDesc = value.element.description + (shouldInsertColumn ? "," : "")
            return result + " " + newDesc + "\n"
        })
        let layoutsDesc = self.layouts.enumerated().reduce("", { result, value in
            let shouldInsertColumn = value.offset < self.layouts.count - 1
            let newDesc = value.element.description + (shouldInsertColumn ? "," : "")
            return result + " " + newDesc + "\n"
        })
        return String(format: "MeshVertexDescriptor: attributes(\n%@) layots: {\n%@}", attributesDesc, layoutsDesc)
    }
}

public extension MeshVertexDescriptor {
    static let defaultVertexDescriptor: MeshVertexDescriptor = {
        var descriptor = MeshVertexDescriptor()
        
        var offset = 0
        
        descriptor.attributes[0].bufferIndex = 0
        descriptor.attributes[0].format = .vector4
        descriptor.attributes[0].offset = offset
        
        offset += MemoryLayout.offset(of: \Vertex.position)!
        
        descriptor.attributes[1].bufferIndex = 0
        descriptor.attributes[1].format = .vector4
        descriptor.attributes[1].offset = offset
        
        offset += MemoryLayout.offset(of: \Vertex.normal)!
        
        descriptor.attributes[2].bufferIndex = 0
        descriptor.attributes[2].format = .vector2
        descriptor.attributes[2].offset = offset
        
        offset += MemoryLayout.offset(of: \Vertex.uv)!
        
        descriptor.attributes[3].bufferIndex = 0
        descriptor.attributes[3].format = .vector4
        descriptor.attributes[3].offset = offset
        
        offset += MemoryLayout.offset(of: \Vertex.color)!
        
        descriptor.layouts[0].stride = offset
        
        return descriptor
    }()
}

#if canImport(MetalKit) && canImport(ModelIO)

import MetalKit
import ModelIO

public extension MeshVertexDescriptor {
    init(mdlVertexDescriptor: MDLVertexDescriptor) {
        
        let attributes: [Attribute] = mdlVertexDescriptor.attributes.compactMap {
            guard
                let attr = ($0 as? MDLVertexAttribute),
                attr.name != "",
                attr.format != .invalid
            else {
                return nil
            }
            
            return Attribute(
                name: attr.name,
                offset: attr.offset,
                bufferIndex: attr.bufferIndex,
                format: VertexFormat(vertexFormat: attr.format))
        }
        
        let layouts: [Layout] = mdlVertexDescriptor.layouts.compactMap {
            guard let layout = ($0 as? MDLVertexBufferLayout), layout.stride > 0 else {
                return nil
            }
            return Layout(stride: layout.stride)
        }
        
        self.init()
        
        self.attributes = VertexDesciptorAttributesArray(buffer: attributes)
        self.layouts = VertexDesciptorLayoutsArray(buffer: layouts)
    }
    
    func makeMTKVertexDescriptor() throws -> MTLVertexDescriptor? {
        let descriptor = self.makeMDLVertexDescriptor()
        return try MTKMetalVertexDescriptorFromModelIOWithError(descriptor)
    }
    
    func makeMDLVertexDescriptor() -> MDLVertexDescriptor {
        let descriptor = MDLVertexDescriptor()
        descriptor.attributes = NSMutableArray(array: self.attributes.buffer.map(makeMDLVertexAttribute))
        descriptor.layouts = NSMutableArray(array: self.layouts.buffer.map { MDLVertexBufferLayout(stride: $0.stride) })
        
        return descriptor
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

func memoryAddress<T: AnyObject>(_ object: T) -> UnsafeMutableRawPointer {
    return Unmanaged.passUnretained(object).toOpaque()
}
