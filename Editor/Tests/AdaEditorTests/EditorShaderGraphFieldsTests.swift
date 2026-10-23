@_spi(AdaEngine) import AdaEngine
import Foundation
import Testing
@testable import AdaEditor

@MainActor
@Suite("Shader Graph material Inspector")
struct EditorShaderGraphFieldsTests {
    @Test func assignmentValuesAndClearingUseStructuredPayloads() throws {
        var payload: EditorComponentPayload = [:]
        let path = EditorShaderGraphFields.path
        path.write("@res://Materials/Test.shadergraph", to: &payload)
        #expect(path.displayValue(in: payload) == "@res://Materials/Test.shadergraph")
        let source = try JSONDecoder().decode(ShaderGraphMaterialSource.self, from: JSONEncoder().encode(payload["graphMaterial"]))
        #expect(source.values.isEmpty)
        path.write("", to: &payload)
        #expect(payload["graphMaterial"] == .null)
    }

    @Test func exposedColorUsesExistingColorControlsAndArrayPersistence() throws {
        let graph = ShaderGraph(target: .sprite, output: "output", nodes: [
            .init(id: "tint", operation: .parameter, type: .color, value: [1, 0, 0, 1], reference: "My tint"),
            .init(id: "output", operation: .output, inputs: ["color": .init("tint")])
        ])
        let source = ShaderGraphMaterialSource(graph: graph)
        var payload: EditorComponentPayload = ["graphMaterial": try JSONDecoder().decode(EditorSceneValue.self, from: JSONEncoder().encode(source))]
        let field = try #require(EditorShaderGraphFields.parameters(in: payload).first)
        #expect(field.kind == .color)
        #expect(field.label == "My tint")
        #expect(field.displayValue(in: payload) == "1, 0, 0, 1")
        field.write("0, 1, 0, 1", to: &payload)
        let material = try #require(try EditorShaderGraphFields.decode(in: payload, target: .sprite))
        #expect(material.value(for: "My tint") == [0, 1, 0, 1])
    }
}
