//
//  Material.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public protocol CustomMaterial: ShaderBindable {
    
    func fragmentShader() throws -> ShaderSource
    
    func vertexShader() throws -> ShaderSource
    
}

public protocol CanvasMaterial: CustomMaterial { }

public extension CanvasMaterial {
    func fragmentShader() throws -> ShaderSource {
        return try ResourceManager.load("Shaders/Vulkan/canvas_mat.glsl#vert", from: .engineBundle)
    }
    
    func vertexShader() throws -> ShaderSource {
        return try ResourceManager.load("Shaders/Vulkan/canvas_mat.glsl#frag", from: .engineBundle)
    }
}

public protocol ShaderBindable {
    static func layout() -> Int
}

public extension ShaderBindable {
    static func layout() -> Int {
        return MemoryLayout<Self>.stride
    }
}

protocol _ShaderBindProperty: AnyObject {
    var propertyName: String { get set }
    var binding: Int { get }
    
    var delegate: MaterialValueDelegate? { get set }
}

protocol _ShaderUniformProperty {
    var valueLayout: Int { get }
}

@propertyWrapper
public final class Uniform<T: ShaderBindable & ShaderUniformValue>: _ShaderBindProperty, _ShaderUniformProperty {
    
    public var wrappedValue: T {
        didSet {
            self.delegate?.updateValue(self.wrappedValue, for: self.propertyName, binding: self.binding)
        }
    }
    
    weak var delegate: MaterialValueDelegate?
    
    var valueLayout: Int { T.layout() }
    public let binding: Int
    internal var propertyName: String = ""
    
    public init(wrappedValue: T, binding: Int) {
        self.wrappedValue = wrappedValue
        self.binding = binding
    }
}

@propertyWrapper
public final class Attribute<T: ShaderUniformValue>: _ShaderBindProperty {
    
    public var wrappedValue: T {
        didSet {
            self.delegate?.updateValue(self.wrappedValue, for: self.propertyName, binding: self.binding)
        }
    }
    
    public let binding: Int
    public let customName: String?
    
    internal var propertyName: String = ""
    
    weak var delegate: MaterialValueDelegate?
    
    public init(wrappedValue: T, binding: Int, customName: String? = nil) {
        self.wrappedValue = wrappedValue
        self.binding = binding
        self.customName = customName
    }
}

@propertyWrapper
public struct TextureBuffer<T: Texture> {
    public var wrappedValue: T
    public let binding: Int
    
    public init(wrappedValue: T, binding: Int) {
        self.wrappedValue = wrappedValue
        self.binding = binding
    }
}

protocol MaterialValueDelegate: AnyObject {
    func updateValue(_ value: ShaderUniformValue, for name: String, binding: Int)
}

@propertyWrapper
public final class MaterialHandle<T: CustomMaterial>: MaterialValueDelegate {
    
    let uniformBufferSet: UniformBufferSet
    
    public var wrappedValue: T
    public var shaderModule: ShaderModule
    
    public init(wrappedValue material: T) {
        self.wrappedValue = material
        self.shaderModule = Self.makeShaderModule(from: material)
        self.uniformBufferSet = Self.reflectMaterial(from: material)
    }
    
    static func makeShaderModule(from material: T) -> ShaderModule {
        do {            
            let fragmentCompiler = try ShaderCompiler(shaderSource: material.fragmentShader())
            let vertexCompiler = try ShaderCompiler(shaderSource: material.vertexShader())
            
            var reflectionData = ShaderReflectionData()
            
            let fragmentShader = try fragmentCompiler.compileShader(for: .fragment)
            let vertexShader = try vertexCompiler.compileShader(for: .vertex)
            
            let module = ShaderModule(
                shaders: [
                    .vertex: vertexShader,
                    .fragment: fragmentShader
                ],
                reflectionData: reflectionData
            )
                                      
            return module
        } catch {
            fatalError("[MaterialHandle] Shader error: \(error.localizedDescription)")
        }
    }
    
    static func reflectMaterial(from material: T) -> UniformBufferSet {
        let uniformBufferSet = RenderEngine.shared.makeUniformBufferSet()
        
        let reflection = Mirror(reflecting: material)
        
        var uniformBuffers = [Int: Int]()
        
        for child in reflection.children {
            guard let bindProperty = child.value as? _ShaderBindProperty else {
                continue
            }
            
            // Get the propertyName of the property. By syntax, the property name is
            // in the form: "_name". Dropping the "_" -> "name"
            let propertyName = String((child.label ?? "").dropFirst())
            bindProperty.propertyName = propertyName
            
            // For update buffers
//            bindProperty.delegate = self
            
            if let uniformProperty = bindProperty as? _ShaderUniformProperty {
                uniformBuffers[bindProperty.binding, default: 0] += uniformProperty.valueLayout
            }
        }
        
        for buffer in uniformBuffers {
            uniformBufferSet.initBuffers(length: buffer.value, binding: buffer.key, set: 0)
        }
        
        return uniformBufferSet
    }
    
    // MARK: Delegate
    
    func updateValue(_ value: ShaderUniformValue, for name: String, binding: Int) {
//        for stage in self.shaderModule.stages {
//            let shader = self.shaderModule.getShader(for: stage)!
//            
//            guard let descriptorSet = shader.reflectionData.descriptorSets[binding] else {
//                continue
//            }
//            
//            guard let uniformBuffer = descriptorSet.uniformsBuffers[binding] else {
//                continue
//            }
//            
//            guard let member = uniformBuffer.members[name] else {
//                continue
//            }
//            
//            if type(of: value).shaderValueType != member.type {
//                assertionFailure("[MaterialHandle] You can't set value for type \(type(of: value).shaderValueType) to uniform member type \(member.type)")
//            }
//            
//            let buffer = self.uniformBufferSet.getBuffer(binding: binding, set: 0, frameIndex: RenderEngine.shared.currentFrameIndex)
//            
//            var value = value
//            buffer.setData(&value, byteCount: member.size, offset: member.offset)
//        }
    }
    
}

public class Material: Resource {
    
    public var resourceName: String = ""
    public var resourcePath: String = ""
    public static var resourceType: ResourceType = .material
    
    let shaderModule: ShaderModule
    let uniformBufferSet: UniformBufferSet
    
    public init(shaderModule: ShaderModule) {
        self.shaderModule = shaderModule
        self.uniformBufferSet = Self.makeUniformBufferSet(from: self.shaderModule)
    }
    
    public required init(asset decoder: AssetDecoder) throws {
        self.shaderModule = try ShaderModule(asset: decoder)
        self.uniformBufferSet = Self.makeUniformBufferSet(from: self.shaderModule)
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        try self.shaderModule.encodeContents(with: encoder)
    }
    
    public func setValue<T: ShaderUniformValue>(_ value: T, for name: String) {
        guard let bufferDesc = self.getUniformDescription(for: name) else {
            return
        }
        
        assert(T.shaderValueType == bufferDesc.type, "Failed to set value with type \(T.shaderValueType) to property with type \(bufferDesc.type)")
        
        let buffer = uniformBufferSet.getBuffer(binding: bufferDesc.binding, set: 0, frameIndex: RenderEngine.shared.currentFrameIndex)
        
        var value = value
        buffer.setData(&value, byteCount: bufferDesc.size, offset: bufferDesc.offset)
    }
    
    public func getValue<T: ShaderUniformValue>(for name: String) -> T? {
        guard let bufferDesc = self.getUniformDescription(for: name) else {
            return nil
        }
        
        assert(T.shaderValueType == bufferDesc.type, "Failed to get value with type \(T.shaderValueType) from property with type \(bufferDesc.type)")
        
        let buffer = uniformBufferSet.getBuffer(binding: bufferDesc.binding, set: 0, frameIndex: RenderEngine.shared.currentFrameIndex)
        return buffer.contents().load(fromByteOffset: bufferDesc.offset, as: T.self)
    }
    
    func getUniformDescription(for name: String) -> ShaderResource.ShaderBufferMember? {
        for buffer in self.shaderModule.reflectionData.shaderBuffers.values {
            if let member = buffer.members[name] {
                return member
            }
        }
        
        return nil
    }
}

fileprivate extension Material {
    static func makeUniformBufferSet(from module: ShaderModule) -> UniformBufferSet {
        let uniformBufferSet = RenderEngine.shared.makeUniformBufferSet()
        
        uniformBufferSet.label = "Material_\(module.resourceName)"
        
        for uniformBuffer in module.reflectionData.shaderBuffers.values {
            uniformBufferSet.initBuffers(
                length: uniformBuffer.size,
                binding: uniformBuffer.binding,
                set: 0
            )
        }
        
        return uniformBufferSet
    }
}
