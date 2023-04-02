//
//  Material.swift
//  
//
//  Created by v.prusakov on 11/3/21.
//

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
    
    public func setResources(_ textures: [Texture], for name: String) {
        MaterialStorage.shared.setResources(textures, for: name, in: self)
    }
    
    public func getResources(for name: String) -> [Texture] {
        return MaterialStorage.shared.getResources(for: name, in: self)
    }
    
    func update() {
        
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
