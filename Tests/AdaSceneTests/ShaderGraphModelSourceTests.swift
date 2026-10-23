import AdaAssets
import AdaECS
@testable import AdaRender
@testable import AdaScene
import Foundation
import Math
import Testing

@MainActor
@Suite("Imported model graph materials")
struct ShaderGraphModelSourceTests {
    @Test func overridesArePerInstanceAndDoNotMutateImportedMaterials() throws {
        let device = HeadlessRenderBackend().renderDevice
        Mesh3DComponent.registerComponent()
        let original = PBRMaterial()
        let texture = Texture2D(
            gpuTexture: device.createTexture(from: TextureDescriptor(width: 1, height: 1, textureUsage: .read, textureType: .texture2D)),
            sampler: device.createSampler(from: SamplerDescriptor()), size: SizeInt(width: 1, height: 1)
        )
        original.baseColorTexture = texture
        original.normalTexture = texture
        original.layerTextures = [.clearcoat: .init(texture: texture), .specular: .init(texture: texture, texCoord: 1)]
        original.baseColorFactor = [0.2, 0.4, 0.6, 1]
        original.metallicFactor = 0.7
        original.roughnessFactor = 0.8
        original.clearcoatFactor = 0.6
        original.sheenColorFactor = [0.1, 0.2, 0.3]
        original.anisotropyStrength = 0.4
        original.textureCoordinates = [1, 0, 1, 0, 1]
        original.textureTransforms[0].offset = [0.2, 0.3]
        let model = ModelAsset3D(
            nodes: [.init(name: "Mesh", transform: .identity, meshIndex: 0, children: [])],
            meshes: [Mesh.generateCube(size: .one, renderDevice: device)],
            materials: [original], scenes: [[0]], defaultScene: 0
        )
        let graph = ShaderGraph(target: .pbrSurface, output: "output", nodes: [
            .init(id: "roughness", operation: .parameter, value: [0.3], reference: "roughness"),
            .init(id: "output", operation: .output, inputs: ["roughness": .init("roughness")])
        ])
        var source = Model3DSource(source: "Model.glb")
        source.graphMaterials = ["0": .init(graph: graph)]
        #expect(try JSONDecoder().decode(Model3DSource.self, from: JSONEncoder().encode(source)) == source)
        let world = World()
        let first = try source.instantiate(model, in: world, under: world.spawn("First"))
        let second = try source.instantiate(model, in: world, under: world.spawn("Second"))
        let a = try #require((first.children.first?.components[Mesh3DComponent.self]?.materials.first as? PBRMaterial)?.graphMaterial)
        let b = try #require((second.children.first?.components[Mesh3DComponent.self]?.materials.first as? PBRMaterial)?.graphMaterial)
        #expect(a !== b)
        try a.setValue([0.8], for: "roughness")
        #expect(b.value(for: "roughness") == [0.3])
        #expect(original.graphMaterial == nil)
        let firstMaterial = try #require(first.children.first?.components[Mesh3DComponent.self]?.materials.first as? PBRMaterial)
        let secondMaterial = try #require(second.children.first?.components[Mesh3DComponent.self]?.materials.first as? PBRMaterial)
        #expect(firstMaterial !== original && firstMaterial !== secondMaterial)
        #expect(firstMaterial.baseColorFactor == original.baseColorFactor)
        #expect(firstMaterial.metallicFactor == 0.7 && firstMaterial.roughnessFactor == 0.8)
        #expect(firstMaterial.shaderFeatures == original.shaderFeatures)
        #expect(firstMaterial.textureCoordinates == original.textureCoordinates)
        #expect(firstMaterial.textureTransforms == original.textureTransforms)
        #expect(firstMaterial.baseColorTexture === texture && firstMaterial.normalTexture === texture)
        #expect(firstMaterial.layerTextures[.clearcoat]?.texture === texture)
        #expect(firstMaterial.layerTextures[.specular]?.texCoord == 1)
        firstMaterial.textureTransforms[0].offset = .zero
        firstMaterial.clearcoatFactor = 0
        #expect(secondMaterial.textureTransforms[0].offset == [0.2, 0.3])
        #expect(secondMaterial.clearcoatFactor == 0.6 && original.clearcoatFactor == 0.6)
        source.graphMaterials = ["99": .init(graph: graph)]
        #expect(throws: ShaderGraphDiagnostic(code: .invalidReference, nodeID: "99")) {
            try source.instantiate(model, in: world, under: world.spawn("Invalid"))
        }
    }
}
