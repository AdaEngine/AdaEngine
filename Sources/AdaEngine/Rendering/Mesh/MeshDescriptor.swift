//
//  MeshDescriptor.swift
//  
//
//  Created by v.prusakov on 11/9/21.
//

import OrderedCollections
import Math

public struct MeshDescriptor {
    
    public internal(set) var buffers: OrderedDictionary<MeshDescriptor.Identifier, AnyMeshBuffer> = [:]
    
    public var name: String
    
    public enum Materials {
        case allFaces(UInt32)
        case perFace([UInt32])
    }
    
    public var materials: Materials = .allFaces(0)
    public var primitiveTopology: Mesh.PrimitiveTopology = .triangleList
    
    public var indicies: [UInt32] = []
    
    init(name: String) {
        self.name = name
        self.buffers[.positions] = AnyMeshBuffer(MeshBuffer<Vector3>([]))
    }
    
    public subscript<S>(semantic: S) -> MeshBuffer<S.Element>? where S : MeshArraySemantic {
        get {
            return self.buffers[semantic.id]?.get(as: S.Element.self)
        }
        set {
            self.buffers[semantic.id] = newValue.flatMap { AnyMeshBuffer($0) }
        }
    }
}

extension Mesh {
    public enum ElementType: UInt8 {
        case int8
        case uint8
        case int16
        case uint16
        case int32
        case uint32
        
        case float
        
        case vector2
        case vector3
        case vector4
    }
    
    public enum ArrayType: UInt8 {
        case vertex
        case normal
        case textureUV
        case color
        case tangent
        case index
    }
    
    public enum PrimitiveTopology: UInt8 {
        case points
        case triangleList
        case triangleStrip
        case lineList
        case lineStrip
    }
}

#if METAL
import Metal

extension Mesh.PrimitiveTopology {
    var metal: MTLPrimitiveType {
        switch self {
        case .lineList: return .line
        case .lineStrip: return .lineStrip
        case .points: return .point
        case .triangleStrip: return .triangleStrip
        case .triangleList: return .triangle
        }
    }
}
#endif

public protocol MeshArraySemantic: Identifiable {
    associatedtype Element

    var id: MeshDescriptor.Identifier { get }
}

extension MeshDescriptor {

    public struct Identifier: Identifiable, Hashable {

        public var id: String {
            return self.name
        }

        public let name: String
        public let isCustom: Bool

        public static let positions: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "positions", isCustom: false)

        public static let normals: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "normals", isCustom: false)

        public static let tangents: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "tangents", isCustom: false)

        public static let textureCoordinates: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "textureCoordinates", isCustom: false)

        public static let colors: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "colors", isCustom: false)
    }

    public struct Semantic<Element> : MeshArraySemantic {

        /// The stable identity of the entity associated with this instance.
        public let id: MeshDescriptor.Identifier

        /// A type representing the stable identity of the entity associated with
        /// an instance.
        public typealias ID = MeshDescriptor.Identifier
    }

    public static let positions: MeshDescriptor.Semantic<Vector3> = MeshDescriptor.Semantic<Vector3>(id: .positions)

    public static let normals: MeshDescriptor.Semantic<Vector3> = MeshDescriptor.Semantic<Vector3>(id: .normals)

    public static let tangents: MeshDescriptor.Semantic<Vector3> = MeshDescriptor.Semantic<Vector3>(id: .tangents)

    public static let textureCoordinates: MeshDescriptor.Semantic<Vector2> = MeshDescriptor.Semantic<Vector2>(id: .textureCoordinates)

    public static let colors: MeshDescriptor.Semantic<Color> = MeshDescriptor.Semantic<Color>(id: .colors)

    public static func custom<Value>(_ name: String, type: Value.Type) -> MeshDescriptor.Semantic<Value> {
        return MeshDescriptor.Semantic<Value>(id: Identifier(name: name, isCustom: true))
    }
}

extension MeshDescriptor {

    public typealias Positions = MeshBuffer<Vector3>

    public typealias Normals = MeshBuffer<Vector3>

    public typealias TextureCoordinates = MeshBuffer<Vector2>

    public typealias Colors = MeshBuffer<Color>

    public var positions: MeshDescriptor.Positions {
        get {
            return self[MeshDescriptor.positions]!
        }

        set {
            self[MeshDescriptor.positions] = newValue
        }
    }

    public var normals: MeshDescriptor.Normals? {
        get {
            return self[MeshDescriptor.normals]
        }

        set {
            self[MeshDescriptor.normals] = newValue
        }
    }

    public var textureCoordinates: MeshDescriptor.TextureCoordinates? {
        get {
            return self[MeshDescriptor.textureCoordinates]
        }

        set {
            self[MeshDescriptor.textureCoordinates] = newValue
        }
    }

    public var colors: MeshDescriptor.Colors? {
        get {
            return self[MeshDescriptor.colors]
        }

        set {
            self[MeshDescriptor.colors] = newValue
        }
    }
}

public extension MeshDescriptor {
    func getMeshVertexBufferDescriptor() -> VertexDescriptor {
        var vertexDescriptor = VertexDescriptor()
        
        var offset: Int = 0
        var index: Int = 0
        for value in buffers.elements {
            let buffer = value.value.buffer
            let attribute = value.key
            
            vertexDescriptor.attributes[index].name = attribute.name
            vertexDescriptor.attributes[index].format = buffer.elementType.vertexFormat
            vertexDescriptor.attributes[index].offset = offset
            
            offset += buffer.elementSize
            index += 1
        }
        
        vertexDescriptor.layouts[0].stride = offset
        
        return vertexDescriptor
    }
    
    func getVertexBufferSize() -> Int {
        var size: Int = 0
        for buffer in buffers.elements.values {
            size += buffer.count
        }
        
        return size
    }
    
    func getIndexBuffer() -> IndexBuffer {
        var indicies = self.indicies
        let indexBuffer = RenderEngine.shared.makeIndexBuffer(
            index: 0,
            format: .uInt32,
            bytes: &indicies,
            length: indicies.count * MemoryLayout<UInt32>.size
        )
        
        return indexBuffer
    }
    
    func getVertexBuffer() -> VertexBuffer {
        var vertexSize = 0
        
        for buffer in buffers.elements.values {
            vertexSize += buffer.buffer.elementSize
        }
        
        let vertexBuffer = RenderEngine.shared.makeVertexBuffer(length: vertexSize * self.getVertexBufferSize(), binding: 0)
        let vertexBufferContents = vertexBuffer.contents()
        
        var attributeOffset: Int = 0
        for buffer in buffers.elements.values {
            let elementSize = buffer.buffer.elementSize
            
            buffer.buffer.iterateByElements { index, pointer in
                let offset = index * vertexSize + attributeOffset
                vertexBufferContents
                    .advanced(by: offset)
                    .copyMemory(from: pointer, byteCount: elementSize)
            }
            
            attributeOffset += elementSize
        }
        
        return vertexBuffer
    }
}

extension Mesh.ElementType {
    var vertexFormat: VertexFormat {
        switch self {
        case .int8:
            return .int
        case .uint8:
            return .uint
        case .int16:
            return .uint
        case .uint16:
            return .uint
        case .int32:
            return .uint
        case .uint32:
            return .uint
        case .float:
            return .float
        case .vector2:
            return .vector2
        case .vector3:
            return .vector3
        case .vector4:
            return .vector4
        }
    }
}
