//
//  Material.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

public protocol ReflectedMaterial: ShaderBindable {
    
    static func vertexShader() throws -> ShaderSource
    
    static func fragmentShader() throws -> ShaderSource
    
    static func configureShaderDefines(
        keys: Set<String>,
        vertexDescriptor: VertexDescriptor
    ) -> [ShaderDefine]
    
    static func configurePipeline(
        keys: Set<String>,
        vertex: Shader,
        fragment: Shader,
        vertexDescriptor: VertexDescriptor
    ) throws -> RenderPipelineDescriptor
}

public protocol CanvasMaterial: ReflectedMaterial { }

public extension CanvasMaterial {
    
    static func vertexShader() throws -> ShaderSource {
        return try ResourceManager.load("Shaders/Vulkan/mesh2d/mesh2d.glsl#vert", from: .engineBundle)
    }
    
    static func fragmentShader() throws -> ShaderSource {
        return try ResourceManager.load("Shaders/Vulkan/mesh2d/mesh2d.glsl#frag", from: .engineBundle)
    }
    
    static func configureShaderDefines(
        keys: Set<String>,
        vertexDescriptor: VertexDescriptor
    ) -> [ShaderDefine] {
        var defines = [ShaderDefine]()
        
        if vertexDescriptor.attributes.containsAttribute(by: MeshDescriptor.positions.id.name) {
            defines.append(.define("VERTEX_POSITIONS"))
        }
        
        if vertexDescriptor.attributes.containsAttribute(by: MeshDescriptor.colors.id.name) {
            defines.append(.define("VERTEX_COLORS"))
        }
        
        if vertexDescriptor.attributes.containsAttribute(by: MeshDescriptor.normals.id.name) {
            defines.append(.define("VERTEX_NORMALS"))
        }
        
        if vertexDescriptor.attributes.containsAttribute(by: MeshDescriptor.textureCoordinates.id.name) {
            defines.append(.define("VERTEX_UVS"))
        }
        
        return defines
    }
    
    static func configurePipeline(
        keys: Set<String>,
        vertex: Shader,
        fragment: Shader,
        vertexDescriptor: VertexDescriptor
    ) throws -> RenderPipelineDescriptor {
        var descriptor = RenderPipelineDescriptor()
        descriptor.debugName = "Canvas Mesh Material \(String(describing: self))"
        descriptor.vertex = vertex
        descriptor.fragment = fragment
        descriptor.vertexDescriptor = vertexDescriptor
        descriptor.backfaceCulling = true
        descriptor.colorAttachments = [
            ColorAttachmentDescriptor(
                format: .bgra8,
                isBlendingEnabled: true
            )
        ]
        
        return descriptor
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
    
    public init(wrappedValue: T, binding: Int, propertyName: String = "") {
        self.wrappedValue = wrappedValue
        self.propertyName = propertyName
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

@dynamicMemberLookup
public final class CustomMaterial<T: ReflectedMaterial>: Material, MaterialValueDelegate {
    
    public var material: T
    
    public init(_ material: T) {
        self.material = material
        
        let shaderSource = ShaderSource()
        
        do {
            let vertexShaderSource = try T.vertexShader()
            let fragmentShaderSource = try T.fragmentShader()
            
            assert(vertexShaderSource.getSource(for: .vertex) != nil, "Failed to load vertex data")
            assert(fragmentShaderSource.getSource(for: .fragment) != nil, "Failed to load fragment data")
            
            shaderSource.setSource(vertexShaderSource.getSource(for: .vertex)!, for: .vertex)
            shaderSource.setSource(fragmentShaderSource.getSource(for: .fragment)!, for: .fragment)
            
            shaderSource.includeSearchPaths.append(contentsOf: vertexShaderSource.includeSearchPaths)
            shaderSource.includeSearchPaths.append(contentsOf: fragmentShaderSource.includeSearchPaths)
            
        } catch {
            print("[CustomMaterial]", error.localizedDescription)
        }
        
        super.init(shaderSource: shaderSource)
        self.reflectMaterial(from: material)
    }
    
    public required init(asset decoder: AssetDecoder) throws {
        fatalError("init(asset:) has not been implemented")
    }
    
    public subscript<Value>(dynamicMember keyPath: WritableKeyPath<T, Value>) -> Value {
        get {
            return self.material[keyPath: keyPath]
        }
        
        set {
            self.material[keyPath: keyPath] = newValue
        }
    }
    
    // MARK: - Mesh
    
    override func collectDefines(for vertexDescriptor: VertexDescriptor, keys: Set<String>) -> [ShaderDefine] {
        return T.configureShaderDefines(keys: keys, vertexDescriptor: vertexDescriptor)
    }
    
    override func configureRenderPipeline(
        for vertexDescriptor: VertexDescriptor,
        keys: Set<String>,
        shaderModule: ShaderModule
    ) -> RenderPipelineDescriptor? {
        do {
            let pipeline = try T.configurePipeline(
                keys: keys,
                vertex: shaderModule.getShader(for: .vertex)!,
                fragment: shaderModule.getShader(for: .fragment)!,
                vertexDescriptor: vertexDescriptor
            )
            
            return pipeline
        } catch {
            print("[CustomMaterial]", error.localizedDescription)
            return nil
        }
    }
    
    func reflectMaterial(from material: T) {
        let reflection = Mirror(reflecting: material)
        
        for child in reflection.children {
            guard let bindProperty = child.value as? _ShaderBindProperty else {
                continue
            }
            
            if bindProperty.propertyName.isEmpty {
                // Get the propertyName of the property. By syntax, the property name is
                // in the form: "_name". Dropping the "_" -> "name"
                let propertyName = String((child.label ?? "").dropFirst())
                bindProperty.propertyName = propertyName
            }
            
            // For update buffers
            bindProperty.delegate = self
        }
    }
    
    // MARK: Delegate
    
    func updateValue(_ value: ShaderUniformValue, for name: String, binding: Int) {
        self.setValue(value, for: name)
    }
}

public class Material: Resource, Hashable {
    
    public var resourceName: String = ""
    public var resourcePath: String = ""
    public static var resourceType: ResourceType = .material
    
    let shaderSource: ShaderSource
    
    init(shaderSource: ShaderSource) {
        self.shaderSource = shaderSource
    }
    
    public required convenience init(asset decoder: AssetDecoder) throws {
        let shaderSource = try ShaderSource(asset: decoder)
        self.init(shaderSource: shaderSource)
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        try self.shaderSource.encodeContents(with: encoder)
    }
    
    public func setValue<T: ShaderUniformValue>(_ value: T, for name: String) {
        MaterialStorage.shared.setValue(value, for: name, in: self)
    }
    
    public func getValue<T: ShaderUniformValue>(for name: String) -> T? {
        return MaterialStorage.shared.getValue(for: name, in: self)
    }
    
    // MARK: Hashable
    
    public static func == (lhs: Material, rhs: Material) -> Bool {
        lhs.shaderSource == rhs.shaderSource
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.shaderSource)
    }
    
    // MARK: Mesh
    
    func collectDefines(for vertexDescriptor: VertexDescriptor, keys: Set<String>) -> [ShaderDefine] {
        fatalErrorMethodNotImplemented()
    }
    
    func configureRenderPipeline(for vertexDescriptor: VertexDescriptor, keys: Set<String>, shaderModule: ShaderModule) -> RenderPipelineDescriptor? {
        fatalErrorMethodNotImplemented()
    }
}

class MaterialStorageData {
    var shaderModule: ShaderModule?
    var uniformBufferSet: UniformBufferSet?
    
    func makeUniformBufferSet(from module: ShaderModule) -> UniformBufferSet {
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

class MaterialStorage {
    
    static let shared: MaterialStorage = MaterialStorage()
    
    var materialData: [Material: MaterialStorageData] = [:]
    
    // MARK: - Material
    
    func setValue<T: ShaderUniformValue>(_ value: T, for name: String, in material: Material) {
        guard let data = self.materialData[material] else {
            return
        }
        
        guard let bufferDesc = self.getUniformDescription(for: name, in: data) else {
            return
        }
        
        assert(T.shaderValueType == bufferDesc.type, "Failed to set value with type \(T.shaderValueType) to property with type \(bufferDesc.type)")
        
        let buffer = data.uniformBufferSet?.getBuffer(binding: bufferDesc.binding, set: 0, frameIndex: RenderEngine.shared.currentFrameIndex)
        
        var value = value
        buffer?.setData(&value, byteCount: bufferDesc.size, offset: bufferDesc.offset)
    }
    
    func getValue<T: ShaderUniformValue>(for name: String, in material: Material) -> T? {
        guard let data = self.materialData[material] else {
            return nil
        }
        
        guard let bufferDesc = self.getUniformDescription(for: name, in: data) else {
            return nil
        }
        
        assert(T.shaderValueType == bufferDesc.type, "Failed to get value with type \(T.shaderValueType) from property with type \(bufferDesc.type)")
        
        let buffer = data.uniformBufferSet?.getBuffer(binding: bufferDesc.binding, set: 0, frameIndex: RenderEngine.shared.currentFrameIndex)
        return buffer?.contents().load(fromByteOffset: bufferDesc.offset, as: T.self)
    }
    
    @inlinable
    func getUniformDescription(for name: String, in material: MaterialStorageData) -> ShaderResource.ShaderBufferMember? {
        guard let reflectionData = material.shaderModule?.reflectionData else {
            return nil
        }
        
        for buffer in reflectionData.shaderBuffers.values {
            if let member = buffer.members[name] {
                return member
            }
        }
        
        return nil
    }
    
    func setMaterialData(_ materialData: MaterialStorageData, for material: Material) {
        self.materialData[material] = materialData
    }
    
    func getMaterialData(for material: Material) -> MaterialStorageData? {
        return self.materialData[material]
    }
}
