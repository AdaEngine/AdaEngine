//
//  MeshVertexDescriptor.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public struct VertexDescriptorAttributesArray: Sequence, Codable {
    
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
    
    public mutating func append(_ attributes: [MeshVertexDescriptor.Attribute]) {
        var lastOffset: Int = 0
        
        for var attribute in attributes {
            if attribute.offset != -1 {
                lastOffset = attribute.offset
            }
            
            attribute.offset = lastOffset
            lastOffset += attribute.format.offset
            
            self.buffer.append(attribute)
        }
    }
}

public struct VertexDescriptorLayoutsArray: Sequence, Codable {
    
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

public enum VertexFormat: UInt, Codable {
    case invalid
    
    case uint
    case char
    case short
    case int
    
    case float
    
    case vector4
    case vector3
    case vector2
    
//    case matrix4x4
//    case matrix3x3
//    case matrix2x2
    
    var offset: Int {
        switch self {
        case .invalid: return 0
        case .uint: return MemoryLayout<UInt>.size
        case .char: return MemoryLayout<UInt8>.size
        case .short: return MemoryLayout<UInt16>.size
        case .int: return MemoryLayout<Int>.size
        case .float: return MemoryLayout<Float>.size
        case .vector4: return MemoryLayout<Vector4>.size
        case .vector3: return MemoryLayout<Vector3>.size
        case .vector2: return MemoryLayout<Vector2>.size
//        case .matrix4x4: return MemoryLayout<Transform3D>.size
//        case .matrix3x3: return MemoryLayout<Transform2D>.size
//        case .matrix2x2: return MemoryLayout<Vector2>.size * 2
        }
    }
}

public struct MeshVertexDescriptor: Codable {
    
    public var attributes: VertexDescriptorAttributesArray
    public var layouts: VertexDescriptorLayoutsArray
    
    public struct Attribute: CustomStringConvertible, Codable {
        public var name: String
        public var offset: Int
        public var bufferIndex: Int
        public var format: VertexFormat
        
        public var description: String {
            return "Attribute: name=\(name) offset=\(offset) bufferIndex=\(bufferIndex) format=\(format)"
        }
        
        public static func attribute(_ format: VertexFormat, name: String, bufferIndex: Int = 0) -> Self {
            Attribute(name: name, offset: -1, bufferIndex: bufferIndex, format: format)
        }
    }
    
    public struct Layout: CustomStringConvertible, Codable {
        public var stride: Int
        
        public var description: String {
            return "Layout: stride=\(stride)"
        }
    }
    
    public init() {
        self.attributes = VertexDescriptorAttributesArray()
        self.layouts = VertexDescriptorLayoutsArray()
    }
    
    init(attributes: VertexDescriptorAttributesArray, layouts: VertexDescriptorLayoutsArray) {
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
        
//        offset += MemoryLayout.offset(of: \Vertex.position)!
        
        descriptor.attributes[1].bufferIndex = 0
        descriptor.attributes[1].format = .vector4
        descriptor.attributes[1].offset = offset
        
//        offset += MemoryLayout.offset(of: \Vertex.normal)!
        
        descriptor.attributes[2].bufferIndex = 0
        descriptor.attributes[2].format = .vector2
        descriptor.attributes[2].offset = offset
        
//        offset += MemoryLayout.offset(of: \Vertex.uv)!
        
        descriptor.attributes[3].bufferIndex = 0
        descriptor.attributes[3].format = .vector4
        descriptor.attributes[3].offset = offset
        
//        offset += MemoryLayout.offset(of: \Vertex.color)!
        
        descriptor.layouts[0].stride = offset
        
        return descriptor
    }()
}

#if METAL

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
        
        self.attributes = VertexDescriptorAttributesArray(buffer: attributes)
        self.layouts = VertexDescriptorLayoutsArray(buffer: layouts)
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

extension VertexFormat {
    var mdlVertexFormat: MDLVertexFormat {
        switch self {
        case .uint: return .uInt
        case .float: return .float
        case .vector4: return .float4
        case .vector3: return .float3
        case .vector2: return .float2
        case .char: return .char
        case .short: return .short
        case .int: return .int
        default:
            return .invalid
        }
    }
    
    init(vertexFormat: MDLVertexFormat) {
        switch vertexFormat {
        case .uInt: self = .uint
        case .float: self = .float
        case .float4: self = .vector4
        case .float3: self = .vector3
        case .float2: self = .vector2
        case .char: self = .char
        case .int: self = .int
        case .short: self = .short
        default:
            self = .invalid
        }
    }
}

extension VertexFormat {
    var metalFormat: MTLVertexFormat {
        switch self {
        case .uint: return MTLVertexFormat.uint
        case .vector4: return .float4
        case .float: return .float
        case .vector3: return .float3
        case .vector2: return .float2
//        case .matrix4x4: return .half4
//        case .matrix3x3: return .half3
//        case .matrix2x2: return .half2
        case .short: return .short
        case .int: return .int
        case .char: return .char
        default:
            return .invalid
        }
    }
}

#endif
