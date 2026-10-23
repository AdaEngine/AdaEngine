import AdaRender

extension Model3DSource {
    /// Imported textures are shared GPU resources. Material factors, UV settings
    /// and graph parameters belong to this model instance and remain independent.
    static func makeGraphOverride(copying original: Material, source: ShaderGraphMaterialSource) throws -> PBRMaterial {
        guard let original = original as? PBRMaterial else {
            throw ShaderGraphDiagnostic(code: .typeMismatch, nodeID: "PBR")
        }
        let graph = try ShaderGraphMaterial(source: source)
        guard graph.program.target == .pbrSurface else { throw ShaderGraphDiagnostic(code: .typeMismatch, nodeID: "PBR") }
        let material = PBRMaterial()
        material.graphMaterial = graph
        material.baseColorFactor = original.baseColorFactor
        material.baseColorTexture = original.baseColorTexture
        material.metallicFactor = original.metallicFactor
        material.roughnessFactor = original.roughnessFactor
        material.metallicRoughnessTexture = original.metallicRoughnessTexture
        material.normalTexture = original.normalTexture
        material.normalScale = original.normalScale
        material.occlusionTexture = original.occlusionTexture
        material.occlusionStrength = original.occlusionStrength
        material.emissiveTexture = original.emissiveTexture
        material.emissiveStrength = original.emissiveStrength
        material.emissiveFactor = original.emissiveFactor
        material.emissiveLightThreshold = original.emissiveLightThreshold
        material.heightTexture = original.heightTexture
        material.heightScale = original.heightScale
        material.heightTextureCoordinate = original.heightTextureCoordinate
        material.heightMaxLayers = original.heightMaxLayers
        material.heightFadeDistance = original.heightFadeDistance
        material.alphaMode = original.alphaMode
        material.alphaCutoff = original.alphaCutoff
        material.doubleSided = original.doubleSided
        material.textureCoordinates = original.textureCoordinates
        material.textureTransforms = original.textureTransforms
        material.ior = original.ior
        material.specularFactor = original.specularFactor
        material.specularColorFactor = original.specularColorFactor
        material.clearcoatFactor = original.clearcoatFactor
        material.clearcoatRoughnessFactor = original.clearcoatRoughnessFactor
        material.sheenColorFactor = original.sheenColorFactor
        material.sheenRoughnessFactor = original.sheenRoughnessFactor
        material.anisotropyStrength = original.anisotropyStrength
        material.anisotropyRotation = original.anisotropyRotation
        material.layerTextures = original.layerTextures
        return material
    }
}
