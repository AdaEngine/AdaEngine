//
//  MeshDescriptor.swift
//  
//
//  Created by v.prusakov on 11/9/21.
//
//
//public struct MeshDescriptor {
//    
//    public private(set) var buffers: [MeshDescriptor.Identifier: AnyMeshArray] = [:]
//    
//    enum Materials {
//        case allFaces(UInt32)
//        case perFace([UInt32])
//    }
//    
//    var materials: Materials = .allFaces(0)
//    
//    init() {
//        self.buffers[.positions] = AnyMeshArray(MeshArray<Vector3>([]))
//    }
//    
//    public subscript<S>(semantic: S) -> MeshArray<S.Element>? where S : MeshArraySemantic {
//        get {
//            return self.buffers[semantic.id]?.get(as: S.Element.self)
//        }
//        set {
//            self.buffers[semantic.id] = newValue.flatMap { AnyMeshArray($0) }
//        }
//    }
//}
//
//extension Mesh {
//    public enum ElementType: UInt8 {
//        case int8
//        case uint8
//        case int16
//        case uint16
//        case int32
//        case uint32
//        
//        case float
//        case double
//        
//        case vector2
//        case vector3
//        case vector4
//    }
//    
//    public enum ArrayType: UInt8 {
//        case vertex
//        case normal
//        case textureUV
//        case color
//        case tangent
//        case index
//    }
//    
//    public enum PrimitiveType: UInt8 {
//        case points
//        case triangles
//        case triangleStrip
//        case lines
//        case lineStrip
//        case lineLoop
//    }
//}
//
//#if canImport(Metal)
//import Metal
//
//extension Mesh.PrimitiveType {
//    var metal: MTLPrimitiveType {
//        switch self {
//        case .lines: return .line
//        case .lineLoop: return .lineStrip
//        case .lineStrip: return .lineStrip
//        case .points: return .point
//        case .triangleStrip: return .triangleStrip
//        case .triangles: return .triangle
//        }
//    }
//}
//#endif

//public protocol MeshArraySemantic: Identifiable {
//    associatedtype Element
//
//    var id: MeshDescriptor.Identifier { get }
//}
//
//extension MeshDescriptor {
//
//    public struct Identifier: Identifiable, Hashable {
//
//        public var id: String {
//            return self.name
//        }
//
//        public let name: String
//        let isCustom: Bool
//
//        public static let positions: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "positions", isCustom: false)
//
//        public static let normals: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "normals", isCustom: false)
//
//        public static let tangents: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "tangents", isCustom: false)
//
//        public static let textureCoordinates: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "textureCoordinates", isCustom: false)
//
//        public static let triangleIndices: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "triangleIndices", isCustom: false)
//
//        public static let colors: MeshDescriptor.Identifier = MeshDescriptor.Identifier(name: "colors", isCustom: false)
//    }
//
//    public struct Semantic<Element> : MeshArraySemantic {
//
//        /// The stable identity of the entity associated with this instance.
//        public let id: MeshDescriptor.Identifier
//
//        /// A type representing the stable identity of the entity associated with
//        /// an instance.
//        public typealias ID = MeshDescriptor.Identifier
//    }
//
//    public static let positions: MeshDescriptor.Semantic<Vector3> = MeshDescriptor.Semantic<Vector3>(id: .positions)
//
//    public static let normals: MeshDescriptor.Semantic<Vector3> = MeshDescriptor.Semantic<Vector3>(id: .normals)
//
//    public static let tangents: MeshDescriptor.Semantic<Vector3> = MeshDescriptor.Semantic<Vector3>(id: .tangents)
//
//    public static let textureCoordinates: MeshDescriptor.Semantic<Vector2> = MeshDescriptor.Semantic<Vector2>(id: .textureCoordinates)
//
//    public static let triangleIndices: MeshDescriptor.Semantic<UInt32> = MeshDescriptor.Semantic<UInt32>(id: .triangleIndices)
//
//    public static let colors: MeshDescriptor.Semantic<Color> = MeshDescriptor.Semantic<Color>(id: .triangleIndices)
//
//    public static func custom<Value>(_ name: String, type: Value.Type) -> MeshDescriptor.Semantic<Value> {
//        return MeshDescriptor.Semantic<Value>(id: Identifier(name: name, isCustom: true))
//    }
//}
//
//extension MeshDescriptor {
//
//    public typealias Positions = MeshArray<Vector3>
//
//    public typealias Normals = MeshArray<Vector3>
//
//    public typealias TextureCoordinates = MeshArray<Vector2>
//
//    public typealias TriangleIndices = MeshArray<UInt32>
//
//    public typealias Colors = MeshArray<Color>
//
//    public var positions: MeshDescriptor.Positions {
//        get {
//            return self[MeshDescriptor.positions]!
//        }
//
//        set {
//            self[MeshDescriptor.positions] = newValue
//        }
//    }
//
//    public var normals: MeshDescriptor.Normals? {
//        get {
//            return self[MeshDescriptor.normals]
//        }
//
//        set {
//            self[MeshDescriptor.normals] = newValue
//        }
//    }
//
//    public var textureCoordinates: MeshDescriptor.TextureCoordinates? {
//        get {
//            return self[MeshDescriptor.textureCoordinates]
//        }
//
//        set {
//            self[MeshDescriptor.textureCoordinates] = newValue
//        }
//    }
//
//    public var colors: MeshDescriptor.Colors? {
//        get {
//            return self[MeshDescriptor.colors]
//        }
//
//        set {
//            self[MeshDescriptor.colors] = newValue
//        }
//    }
//}
