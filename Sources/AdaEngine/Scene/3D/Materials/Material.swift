//
//  Material.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

//
//public class Material: Resource {
//    public required init(asset decoder: AssetDecoder) throws {
//        fatalError()
//    }
//
//    public func encodeContents(with encoder: AssetEncoder) throws {
//        fatalError()
//    }
//
//    public static var resourceType: ResourceType = .material
//    public var resourcePath: String = ""
//    public var resourceName: String = ""
//
//    init(shader: Shader) {
//
//    }
//
//}

public protocol Material: ShaderBindable {
    
    func fragmentShader() -> ShaderSource
    
    func vertexShader() -> ShaderSource
    
}

public protocol ShaderBindable {
    func layout() -> Int
}

public extension ShaderBindable {
    func layout() -> Int {
        return MemoryLayout<Self>.stride
    }
}

@propertyWrapper
public struct Uniform<T: ShaderBindable> {

    public var wrappedValue: T
    public let slot: Int

    public init(wrappedValue: T, slot: Int) {
        self.wrappedValue = wrappedValue
        self.slot = slot
    }
}

@propertyWrapper
public struct Attribute<T: ShaderPrimitive> {

    public var wrappedValue: T
    public let slot: Int
    public let customName: String?

    public init(wrappedValue: T, slot: Int, customName: String? = nil) {
        self.wrappedValue = wrappedValue
        self.slot = slot
        self.customName = customName
    }
}

public protocol ShaderPrimitive {
    var vertexFormat: VertexFormat { get }
}

@propertyWrapper
public struct TextureBuffer<T: Texture> {
    public var wrappedValue: T
    public let slot: Int

    public init(wrappedValue: T, slot: Int) {
        self.wrappedValue = wrappedValue
        self.slot = slot
    }
}

struct MyMaterial {
//    @Uniform(slot: 0) var color: Color = .red
    @Attribute(slot: 1) var value: Float = 0
}

extension Color: ShaderPrimitive, ShaderBindable {
    public var vertexFormat: VertexFormat { .vector4 }
}

extension Vector2: ShaderPrimitive, ShaderBindable {
    public var vertexFormat: VertexFormat { .vector2 }
}

extension Vector3: ShaderPrimitive, ShaderBindable {
    public var vertexFormat: VertexFormat { .vector3 }
}

extension Vector4: ShaderPrimitive, ShaderBindable {
    public var vertexFormat: VertexFormat { .vector4 }
}

extension Float: ShaderPrimitive, ShaderBindable {
    public var vertexFormat: VertexFormat { .float }
}

extension Int: ShaderPrimitive, ShaderBindable {
    public var vertexFormat: VertexFormat { .int }
}

extension UInt: ShaderPrimitive, ShaderBindable {
    public var vertexFormat: VertexFormat { .uint }
}

extension UInt8: ShaderPrimitive, ShaderBindable {
    public var vertexFormat: VertexFormat { .char }
}

extension UInt16: ShaderPrimitive, ShaderBindable {
    public var vertexFormat: VertexFormat { .short }
}

enum ShaderMaterialProcessor {
    
//    static let entryPointCallerRegex: String = "\[\[(\w+)\]\]\s*(?:\[[^\]]+\])*\s*\w+\s([^\\(]+)"
    
    static func process(_ source: String) throws -> String {
//        let entryPointRegex = try NSRegularExpression(pattern: self.entryPointRegex, options: 0)
//        let entryPointRegexCaller = try NSRegularExpression(pattern: self.entryPointCallerRegex, options: 0)
        
        var newString = source
        
        
        return source
    }
}

class MaterialHandle {
         
}
