//
//  Material.swift
//  AdaEngine
//
//  Created by v.prusakov on 11/3/21.
//

import AdaAssets
import AdaUtils

// TODO: (Vlad) I think that `MaterialStorage` isn't great solution.

/// A type that describes the material aspects of a mesh, like color and texture.
///
/// In AdaEngine, a material defines the surface properties of a 3D and 2D model. It specifies how AdaEngine renders the entity, 
/// including its color and whether it’s shiny or reflective. 
/// Some components like `Mesh2D` may have one material that defines the way AdaEngine renders the entire entity,
/// or it may have several that define the look of different parts of the model.
public class Material: Asset, Hashable, @unchecked Sendable {
    
    public var assetMetaInfo: AssetMetaInfo?
    
    public let rid = RID()

    public let shaderSource: ShaderSource

    /// Create a new material from shader source.
    public init(shaderSource: ShaderSource) {
        self.shaderSource = shaderSource
    }
    
    public required convenience init(from assetDecoder: AssetDecoder) throws {
        let shaderSource = try ShaderSource(from: assetDecoder)
        self.init(shaderSource: shaderSource)
    }
    
    public func encodeContents(with encoder: AssetEncoder) throws {
        try self.shaderSource.encodeContents(with: encoder)
    }
    
    public static func extensions() -> [String] {
        ["mat"]
    }
    
    /// Set the new value for material.
    public func setValue<T: ShaderUniformValue>(_ value: T, for name: String) {
        unsafe MaterialStorage.shared.setValue(value, for: name, in: self)
    }
    
    /// Get value from material.
    public func getValue<T: ShaderUniformValue>(for name: String) -> T? {
        return unsafe MaterialStorage.shared.getValue(for: name, in: self)
    }
    
    /// Set one or more textures for material.
    public func setTexture(_ texture: Texture, for name: String) {
        unsafe MaterialStorage.shared.setTexture(texture, for: name, in: self)
    }

    /// Set one or more samplers for material.
    public func setSampler(_ sampler: any Sampler, for name: String) {
        unsafe MaterialStorage.shared.setSampler(sampler, for: name, in: self)
    }
    
    /// Get textures from material.
    public func getTexture(for name: String) -> Texture? {
        return unsafe MaterialStorage.shared.getTexture(for: name, in: self)
    }

    /// Get sampler from material.
    public func getSampler(for name: String) -> (any Sampler)? {
        return unsafe MaterialStorage.shared.getSampler(for: name, in: self)
    }
    
    /// Updates material values.
    open func update() { }
    
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
    open func collectDefines(for vertexDescriptor: VertexDescriptor, keys: Set<String>) -> [ShaderDefine] {
        fatalErrorMethodNotImplemented()
    }
    
    /// Create render pipeline descriptor for passed vertex descriptor, keys and compiled shader module.
    open func configureRenderPipeline(
        for vertexDescriptor: VertexDescriptor,
        keys: Set<String>,
        shaderModule: ShaderModule
    ) -> RenderPipelineDescriptor? {
        fatalErrorMethodNotImplemented()
    }
}
