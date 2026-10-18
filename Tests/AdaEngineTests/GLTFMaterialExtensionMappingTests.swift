import AdaAssets
@_spi(Internal) @testable import AdaRender
@testable import AdaScene
import Math
import Testing

@Suite
struct GLTFMaterialExtensionMappingTests {
    @Test
    func importedExtensionValuesReachThePBRMaterial() throws {
        var transforms = Array(repeating: GLTFImportResult.TextureTransform.identity, count: 5)
        transforms[0] = .init(offset: Vector2(0.1, 0.2), rotation: 0.5, scale: Vector2(2, 3))
        transforms[2] = .init(scale: Vector2(4, 4))
        let source = GLTFImportResult.Material(
            name: nil,
            baseColorFactor: .one,
            baseColorTextureIndex: nil,
            metallicFactor: 0,
            roughnessFactor: 0.4,
            metallicRoughnessTextureIndex: nil,
            normalTextureIndex: nil,
            textureTransforms: transforms,
            ior: 1.33,
            specularFactor: 0.6,
            specularColorFactor: Vector3(1, 0.8, 0.6),
            clearcoatFactor: 0.7,
            clearcoatRoughnessFactor: 0.15
        )
        let result = GLTFImportResult(nodes: [], meshes: [], materials: [source], textures: [], images: [], scenes: [], defaultScene: nil)
        let material = try #require(ModelAsset3D.makeMaterials(result).first as? PBRMaterial)
        #expect(material.textureTransforms[0] == PBRTextureTransform(offset: Vector2(0.1, 0.2), rotation: 0.5, scale: Vector2(2, 3)))
        #expect(material.textureTransforms[2] == PBRTextureTransform(scale: Vector2(4, 4)))
        #expect(material.textureTransforms[1] == .identity)
        #expect(material.ior == 1.33 && material.specularFactor == 0.6)
        #expect(material.specularColorFactor == Vector3(1, 0.8, 0.6))
        #expect(material.clearcoatFactor == 0.7 && material.clearcoatRoughnessFactor == 0.15)
    }
}
