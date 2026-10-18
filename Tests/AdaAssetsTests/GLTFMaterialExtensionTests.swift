import AdaAssets
import Foundation
import Math
import Testing

@Suite
struct GLTFMaterialExtensionTests {
    private func load(material: [String: Any], used: [String]? = nil, required: [String]? = nil) throws -> GLTFImportResult {
        var document: [String: Any] = [
            "asset": ["version": "2.0"],
            "images": [["uri": "data:application/octet-stream;base64,AQID"]],
            "textures": [["source": 0]],
            "materials": [material],
        ]
        if let used { document["extensionsUsed"] = used }
        if let required { document["extensionsRequired"] = required }
        return try NativeGLTFLoader().load(data: JSONSerialization.data(withJSONObject: document))
    }

    private func transform(_ values: [String: Any]) -> [String: Any] {
        ["extensions": ["KHR_texture_transform": values]]
    }

    @Test
    func texturesWithoutATransformKeepTheIdentity() throws {
        let material = try #require(load(material: ["pbrMetallicRoughness": ["baseColorTexture": ["index": 0]]]).materials.first)
        #expect(material.textureTransforms == Array(repeating: .identity, count: 5))
        #expect(material.ior == 1.5 && material.specularFactor == 1 && material.specularColorFactor == .one)
    }

    @Test
    func importsTextureTransformsPerSlot() throws {
        let base = ["index": 0].merging(transform(["offset": [0.25, 0.5], "rotation": 1.5, "scale": [2, 3]])) { $1 }
        let normal = ["index": 0].merging(transform(["scale": [4, 4]])) { $1 }
        let material = try #require(load(material: [
            "pbrMetallicRoughness": ["baseColorTexture": base],
            "normalTexture": normal,
        ], used: ["KHR_texture_transform"]).materials.first)
        #expect(material.textureTransforms[0] == .init(offset: Vector2(0.25, 0.5), rotation: 1.5, scale: Vector2(2, 3)))
        #expect(material.textureTransforms[2] == .init(offset: .zero, rotation: 0, scale: Vector2(4, 4)))
        #expect(material.textureTransforms[1] == .identity && material.textureTransforms[4] == .identity)
    }

    @Test
    func aTransformCanSelectAnotherUVSet() throws {
        let texture = ["index": 0, "texCoord": 0].merging(transform(["texCoord": 1])) { $1 }
        let material = try #require(load(material: ["emissiveTexture": texture]).materials.first)
        #expect(material.textureCoordinates == [0, 0, 0, 0, 1])
    }

    private func object(_ json: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    @Test(arguments: [#"{"offset":[1]}"#, #"{"scale":[1,2,3]}"#, #"{"texCoord":5}"#])
    func rejectsMalformedTransforms(json: String) throws {
        let values = try object(json)
        let texture = ["index": 0].merging(transform(values)) { $1 }
        #expect(throws: NativeGLTFLoader.GLTFError.invalidMaterial(0)) {
            try load(material: ["pbrMetallicRoughness": ["baseColorTexture": texture]])
        }
    }

    @Test
    func importsIORAndSpecular() throws {
        let material = try #require(load(material: ["extensions": [
            "KHR_materials_ior": ["ior": 1.33],
            "KHR_materials_specular": ["specularFactor": 0.5, "specularColorFactor": [1, 0.5, 0.25]],
        ]], used: ["KHR_materials_ior", "KHR_materials_specular"]).materials.first)
        #expect(material.ior == 1.33 && material.specularFactor == 0.5)
        #expect(material.specularColorFactor == Vector3(1, 0.5, 0.25))
    }

    @Test(arguments: [
        #"{"KHR_materials_ior":{"ior":0.5}}"#,
        #"{"KHR_materials_ior":{"ior":500}}"#,
        #"{"KHR_materials_specular":{"specularFactor":-1}}"#,
        #"{"KHR_materials_specular":{"specularColorFactor":[1,1]}}"#,
    ])
    func rejectsOutOfRangeReflectance(json: String) throws {
        let extensions = try object(json)
        #expect(throws: NativeGLTFLoader.GLTFError.invalidMaterial(0)) { try load(material: ["extensions": extensions]) }
    }

    @Test
    func importsClearcoat() throws {
        let material = try #require(load(material: ["extensions": [
            "KHR_materials_clearcoat": ["clearcoatFactor": 0.8, "clearcoatRoughnessFactor": 0.1],
        ]], used: ["KHR_materials_clearcoat"]).materials.first)
        #expect(material.clearcoatFactor == 0.8 && material.clearcoatRoughnessFactor == 0.1)
        let plain = try #require(load(material: [:]).materials.first)
        #expect(plain.clearcoatFactor == 0 && plain.clearcoatRoughnessFactor == 0)
    }

    @Test(arguments: [
        #"{"KHR_materials_clearcoat":{"clearcoatFactor":1.5}}"#,
        #"{"KHR_materials_clearcoat":{"clearcoatFactor":-0.1}}"#,
        #"{"KHR_materials_clearcoat":{"clearcoatRoughnessFactor":2}}"#,
    ])
    func rejectsOutOfRangeClearcoat(json: String) throws {
        let extensions = try object(json)
        #expect(throws: NativeGLTFLoader.GLTFError.invalidMaterial(0)) { try load(material: ["extensions": extensions]) }
    }

    @Test
    func clearcoatTexturesAreReportedAsSkipped() throws {
        let result = try load(
            material: ["extensions": ["KHR_materials_clearcoat": ["clearcoatFactor": 1, "clearcoatNormalTexture": ["index": 0]]]],
            used: ["KHR_materials_clearcoat"]
        )
        #expect(result.warnings.count == 1 && result.warnings[0].contains("KHR_materials_clearcoat") && result.warnings[0].contains("Material 0"))
    }

    @Test
    func importsSheenAndAnisotropy() throws {
        let material = try #require(load(material: ["extensions": [
            "KHR_materials_sheen": ["sheenColorFactor": [0.9, 0.5, 0.2], "sheenRoughnessFactor": 0.4],
            "KHR_materials_anisotropy": ["anisotropyStrength": 0.6, "anisotropyRotation": 1.2],
        ]], used: ["KHR_materials_sheen", "KHR_materials_anisotropy"]).materials.first)
        #expect(material.sheenColorFactor == Vector3(0.9, 0.5, 0.2) && material.sheenRoughnessFactor == 0.4)
        #expect(material.anisotropyStrength == 0.6 && material.anisotropyRotation == 1.2)
        let plain = try #require(load(material: [:]).materials.first)
        #expect(plain.sheenColorFactor == .zero && plain.sheenRoughnessFactor == 0)
        #expect(plain.anisotropyStrength == 0 && plain.anisotropyRotation == 0)
    }

    @Test(arguments: [
        #"{"KHR_materials_sheen":{"sheenColorFactor":[2,0,0]}}"#,
        #"{"KHR_materials_sheen":{"sheenColorFactor":[1,1]}}"#,
        #"{"KHR_materials_sheen":{"sheenRoughnessFactor":-1}}"#,
        #"{"KHR_materials_anisotropy":{"anisotropyStrength":2}}"#,
        #"{"KHR_materials_anisotropy":{"anisotropyStrength":-0.5}}"#,
    ])
    func rejectsOutOfRangeSheenAndAnisotropy(json: String) throws {
        let extensions = try object(json)
        #expect(throws: NativeGLTFLoader.GLTFError.invalidMaterial(0)) { try load(material: ["extensions": extensions]) }
    }

    @Test
    func sheenAndAnisotropyTexturesAreReportedAsSkipped() throws {
        let result = try load(material: ["extensions": [
            "KHR_materials_sheen": ["sheenColorTexture": ["index": 0]],
            "KHR_materials_anisotropy": ["anisotropyTexture": ["index": 0]],
        ]], used: ["KHR_materials_sheen", "KHR_materials_anisotropy"])
        #expect(result.warnings.count == 2)
        #expect(result.warnings.contains { $0.contains("KHR_materials_sheen") } && result.warnings.contains { $0.contains("KHR_materials_anisotropy") })
    }

    @Test
    func unsupportedUsedExtensionsLoadWithAWarning() throws {
        let result = try load(material: [:], used: ["KHR_materials_transmission", "KHR_texture_transform"])
        #expect(result.warnings.count == 1)
        #expect(result.warnings.first?.contains("KHR_materials_transmission") == true)
    }

    @Test
    func unsupportedRequiredExtensionsStillFail() {
        #expect(throws: NativeGLTFLoader.GLTFError.unsupportedRequiredExtension("KHR_materials_transmission")) {
            try load(material: [:], used: ["KHR_materials_transmission"], required: ["KHR_materials_transmission"])
        }
    }

    @Test
    func specularTexturesAreReportedAsSkipped() throws {
        let result = try load(material: ["extensions": ["KHR_materials_specular": ["specularTexture": ["index": 0]]]])
        #expect(result.warnings.contains { $0.contains("Material 0") && $0.contains("texture") })
    }

    @Test
    func theSupportedListNamesEveryImplementedExtension() {
        let supported = NativeGLTFLoader.supportedExtensions
        for name in ["KHR_texture_transform", "KHR_materials_ior", "KHR_materials_specular", "KHR_materials_clearcoat", "KHR_materials_sheen", "KHR_materials_anisotropy", "KHR_materials_emissive_strength", "KHR_mesh_quantization"] {
            #expect(supported.contains(name))
        }
    }
}
