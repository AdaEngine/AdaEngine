@testable import AdaRender
import AdaScene
import Foundation
import Testing

@MainActor @Suite("Portable primitive graph materials", .serialized)
struct ShaderGraphPrimitiveSourceTests {
    private func device() throws -> RenderDevice {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        return unsafe RenderEngine.shared.renderDevice
    }

    @Test func primitiveAndIndependentGraphValuesSurviveThePortableCodec() throws {
        let graph = ShaderGraph(target: .pbrSurface, output: "output", nodes: [
            .init(id: "tint", operation: .parameter, type: .color, value: [1, 1, 1, 1], reference: "tint"),
            .init(id: "output", operation: .output, inputs: ["baseColor": .init("tint")])
        ])
        let source = PrimitiveMesh3DSource(
            mesh: .sphere,
            size: 2,
            metallic: 0.3,
            roughness: 0.7,
            castShadows: false,
            graphMaterial: .init(graph: graph, values: ["tint": [0.2, 0.5, 0.8, 1]])
        )
        let restored = try JSONDecoder().decode(PrimitiveMesh3DSource.self, from: JSONEncoder().encode(source))
        #expect(restored.mesh == .sphere && restored.size == 2)
        let first = try restored.makeComponent(renderDevice: device())
        let second = try restored.makeComponent(renderDevice: device())
        let firstMaterial = try #require(first.materials.first as? PBRMaterial)
        let secondMaterial = try #require(second.materials.first as? PBRMaterial)
        #expect(firstMaterial.metallicFactor == 0.3 && firstMaterial.roughnessFactor == 0.7)
        #expect(!first.castShadows && first.receiveShadows)
        try firstMaterial.graphMaterial?.setValue([1, 0, 0, 1], for: "tint")
        #expect(secondMaterial.graphMaterial?.value(for: "tint") == [0.2, 0.5, 0.8, 1])
    }

    @Test func invalidPrimitiveAndWrongGraphTargetFailExplicitly() throws {
        var source = PrimitiveMesh3DSource(size: -.infinity)
        #expect(throws: (any Error).self) { try source.validate() }
        source.size = 1
        source.graphMaterial = .init(graph: ShaderGraph(target: .sprite, output: "output", nodes: [.init(id: "output", operation: .output)]))
        #expect(throws: ShaderGraphDiagnostic.self) { try source.makeComponent(renderDevice: device()) }
    }
}
