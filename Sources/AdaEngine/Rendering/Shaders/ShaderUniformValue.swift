//
//  ShaderUniformValue.swift
//  
//
//  Created by v.prusakov on 3/23/23.
//

public protocol ShaderUniformValue {
    static var shaderValueType: ShaderValueType { get }
}

extension Color: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .vec4
}

extension Vector2: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .vec2
}

extension Vector3: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .vec3
}

extension Vector4: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .vec4
}

extension Float: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .float
}

extension Int: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .int
}

extension UInt: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .uint
}

extension UInt8: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .char
}

extension UInt16: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .short
}

extension Transform3D: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .mat4
}

extension Transform2D: ShaderUniformValue, ShaderBindable {
    public static let shaderValueType: ShaderValueType = .mat3
}

public enum ShaderValueType: String, Codable {
    case vec2
    case vec3
    case vec4
    
    case mat4
    case mat3
    
    case float
    case half
    case int
    case uint
    case short
    case char
    case bool
    
    case structure
    
    case none
}
