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
        source.graphMaterials = ["99": .init(graph: graph)]
        #expect(throws: ShaderGraphDiagnostic(code: .invalidReference, nodeID: "99")) {
            try source.instantiate(model, in: world, under: world.spawn("Invalid"))
        }
    }
}
