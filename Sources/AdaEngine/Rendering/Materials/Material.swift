//
//  Material.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/3/21.
//

// TODO: (Vlad) I think that `MaterialStorage` isn't great solution.

/// A type that describes the material aspects of a mesh, like color and texture.
///
/// In AdaEngine, a material defines the surface properties of a 3D and 2D model. It specifies how AdaEngine renders the entity, including its color and whether it’s shiny or reflective. Some components like ``Mesh2DComponent`` may have one material that defines the way AdaEngine renders the entire entity, or it may have several that define the look of different parts of the model.
public class Material: Resource, Hashable {
    
    public var resourceName: String = ""
    public var resourcePath: String = ""
    public static var resourceType: ResourceType = .material
    
    let rid = RID()
    
    let shaderSource: ShaderSource
    
    /// Create a new material from shader source.
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
    
    /// Set the new value for material.
    public func setValue<T: ShaderUniformValue>(_ value: T, for name: String) {
        MaterialStorage.shared.setValue(value, for: name, in: self)
    }
    
    /// Get value from material.
    public func getValue<T: ShaderUniformValue>(for name: String) -> T? {
        return MaterialStorage.shared.getValue(for: name, in: self)
    }
    
    /// Set one or more textures for material.
    public func setResources(_ textures: [Texture], for name: String) {
        MaterialStorage.shared.setResources(textures, for: name, in: self)
    }
    
    /// Get textures from material.
    public func getResources(for name: String) -> [Texture] {
        return MaterialStorage.shared.getResources(for: name, in: self)
    }
    
    /// Updates material values.
    func update() { }
    
    // MARK: Hashable
    
    public static func == (lhs: Material, rhs: Material) -> Bool {
        lhs.shaderSource == rhs.shaderSource
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.shaderSource)
    }
    
    // MARK: Mesh
    
    // TODO: (Vlad) I don't like current implementation for materials and shaders and methods below is a reason.
    
    /// Collection defines for passed vertex descriptor and collection of keys.
    func collectDefines(for vertexDescriptor: VertexDescriptor, keys: Set<String>) -> [ShaderDefine] {
        fatalErrorMethodNotImplemented()
    }
    
    /// Create render pipeline descriptor for passed vertex descriptor, keys and compiled shader module.
    func configureRenderPipeline(for vertexDescriptor: VertexDescriptor, keys: Set<String>, shaderModule: ShaderModule) -> RenderPipelineDescriptor? {
        fatalErrorMethodNotImplemented()
    }
}
