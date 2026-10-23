import AdaAssets
import Foundation
import Testing

@testable import AdaRender

@Suite("Typed shader graphs")
struct ShaderGraphTests {
    private func sprite() -> ShaderGraph {
        ShaderGraph(target: .sprite, output: "output", nodes: [
            .init(id: "tint", operation: .constant, type: .color, value: [1, 0.5, 0, 1]),
            .init(id: "output", operation: .output, inputs: ["color": .init("tint")])
        ])
    }

    @Test func graphFileRoundTrip() throws {
        var graph = sprite()
        graph.layout["tint"] = .init(x: 30, y: -10)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).shadergraph")
        defer { try? FileManager.default.removeItem(at: file) }
        try JSONEncoder().encode(graph).write(to: file)
        let decoded = try JSONDecoder().decode(ShaderGraph.self, from: Data(contentsOf: file))
        #expect(decoded == graph)
        #expect(try decoded.lowered() == graph.lowered())
        #expect(ShaderGraphAsset.extensions() == ["shadergraph"])
    }

    @Test func loweringIgnoresOrderingLayoutAndUnusedComputations() throws {
        var graph = sprite()
        let expected = try graph.lowered()
        graph.nodes.reverse()
        graph.nodes.append(.init(id: "unused", operation: .constant, value: [42]))
        graph.layout["tint"] = .init(x: 900, y: 500)
        #expect(try graph.lowered() == expected)
        #expect(expected.instructions.map(\.nodeID) == ["tint", "output"])
    }

    @Test func assetManagerPreservesMetadataAndGraphContents() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).shadergraph")
        defer { try? FileManager.default.removeItem(at: path) }
        let graph = sprite()
        try await AssetsManager.save(ShaderGraphAsset(graph: graph), at: path.path)
        let loaded = try await AssetsManager.loadFresh(ShaderGraphAsset.self, at: path.path)
        #expect(loaded.graph == graph)
        #expect(loaded.assetMetaInfo?.assetPath == path.path)
        #expect(try loaded.graph.lowered() == graph.lowered())
        let future = Data(#"{"version":999,"futureSchema":true}"#.utf8)
        try future.write(to: path)
        await #expect(throws: (any Error).self) {
            try await AssetsManager.loadFresh(ShaderGraphAsset.self, at: path.path)
        }
        #expect(try Data(contentsOf: path) == future)
    }

    @Test func scalarBroadcastIsExplicit() throws {
        var graph = sprite()
        graph.nodes += [
            .init(id: "intensity", operation: .constant, value: [0.5]),
            .init(id: "multiply", operation: .multiply, type: .color, inputs: ["a": .init("tint"), "b": .init("intensity")])
        ]
        graph.nodes[1].inputs["color"] = .init("multiply")
        let program = try graph.lowered()
        let multiply = try #require(program.instructions.first { $0.nodeID == "multiply" })
        #expect(multiply.inputs["a"]?.conversion == .identity)
        #expect(multiply.inputs["b"]?.conversion == .scalarBroadcast)
        #expect(multiply.inputs["b"]?.type == .color)
    }

    @Test func unreachableDependentsCannotReorderTheProgram() throws {
        var graph = sprite()
        graph.nodes.append(.init(id: "alpha", operation: .constant, value: [1]))
        graph.nodes[1].inputs["alpha"] = .init("alpha")
        let expected = try graph.lowered()
        graph.nodes.append(.init(id: "000unused", operation: .multiply, type: .color, inputs: ["a": .init("tint"), "b": .init("tint")]))
        #expect(try graph.lowered() == expected)
    }

    @Test func texturePortsAndPBRSurfaceAreTyped() throws {
        let graph = ShaderGraph(target: .pbrSurface, output: "output", nodes: [
            .init(id: "texture", operation: .texture, type: .texture2D, reference: "Textures/Stone.png"),
            .init(id: "uv", operation: .uv, type: .vector2),
            .init(id: "sample", operation: .sampleTexture, type: .vector4, inputs: ["texture": .init("texture"), "uv": .init("uv")]),
            .init(id: "output", operation: .output, inputs: ["baseColor": .init("sample", port: "color"), "alpha": .init("sample", port: "alpha")])
        ])
        let program = try graph.lowered()
        #expect(program.instructions.map(\.nodeID) == ["texture", "uv", "sample", "output"])
        #expect(program.instructions.last?.inputs["baseColor"]?.type == .color)
        #expect(program.instructions.last?.inputs["alpha"]?.type == .float)
    }

    @Test func futureVersionsAreRejectedBeforeDecodingTheirSchema() throws {
        let data = Data(#"{"version":999,"futureSchema":true}"#.utf8)
        #expect(throws: ShaderGraphDiagnostic(code: .unsupportedVersion)) { try JSONDecoder().decode(ShaderGraph.self, from: data) }
        var graph = sprite()
        graph.version = 0
        #expect(throws: ShaderGraphDiagnostic(code: .unsupportedVersion)) { try graph.lowered() }
    }

    @Test func unknownOperationsKeepTheirNodeIdentity() throws {
        var graph = sprite()
        graph.nodes[0].kind = "futureEffect"
        let decoded = try JSONDecoder().decode(ShaderGraph.self, from: JSONEncoder().encode(graph))
        #expect(decoded.nodes[0].kind == "futureEffect")
        #expect(throws: ShaderGraphDiagnostic(code: .unknownOperation, nodeID: "tint")) { try decoded.lowered() }
    }

    @Test func malformedLinksAreAttributedToTheirDestination() {
        var graph = sprite()
        graph.nodes[1].inputs["color"] = .init("missing")
        #expect(throws: ShaderGraphDiagnostic(code: .missingNode, nodeID: "output", port: "color")) { try graph.lowered() }
        graph.nodes[1].inputs["color"] = .init("tint", port: "missing")
        #expect(throws: ShaderGraphDiagnostic(code: .unknownPort, nodeID: "output", port: "color")) { try graph.lowered() }
        graph.nodes[1].inputs = ["roughness": .init("tint")]
        #expect(throws: ShaderGraphDiagnostic(code: .unknownInput, nodeID: "output", port: "roughness")) { try graph.lowered() }
    }

    @Test func mismatchedVectorAndColorTypesAreRejected() {
        var graph = sprite()
        graph.nodes[0].type = .vector4
        #expect(throws: ShaderGraphDiagnostic(code: .typeMismatch, nodeID: "output", port: "color", expected: .color, actual: .vector4)) { try graph.lowered() }
        graph.nodes[0].type = .vector2
        graph.nodes[0].value = [1, 1]
        #expect(throws: ShaderGraphDiagnostic(code: .typeMismatch, nodeID: "output", port: "color", expected: .color, actual: .vector2)) { try graph.lowered() }
    }

    @Test func invalidLiteralShapesAndNonfiniteValuesAreRejected() {
        let invalidValues: [[Float]] = [[], [1, 2], [1, 2, 3, .nan], [1, 2, 3, .infinity]]
        for value in invalidValues {
            var graph = sprite()
            graph.nodes[0].value = value
            #expect(throws: ShaderGraphDiagnostic(code: .invalidLiteral, nodeID: "tint")) { try graph.lowered() }
        }
    }

    @Test func duplicateNodesAndMissingOutputsAreRejected() {
        var graph = sprite()
        graph.nodes.append(graph.nodes[0])
        #expect(throws: ShaderGraphDiagnostic(code: .duplicateNode, nodeID: "tint")) { try graph.lowered() }
        graph = sprite()
        graph.output = "tint"
        #expect(throws: ShaderGraphDiagnostic(code: .missingOutput, nodeID: "tint")) { try graph.lowered() }
        graph = sprite()
        graph.nodes.append(.init(id: "secondOutput", operation: .output))
        #expect(throws: ShaderGraphDiagnostic(code: .multipleOutputs, nodeID: "secondOutput")) { try graph.lowered() }
        graph = sprite()
        graph.nodes[0].id = ""
        #expect(throws: ShaderGraphDiagnostic(code: .invalidNodeID, nodeID: "")) { try graph.lowered() }
    }

    @Test func unusedCyclesAreStillRejected() {
        var graph = sprite()
        graph.nodes.append(.init(id: "cycle", operation: .add, inputs: ["a": .init("cycle"), "b": .init("cycle")]))
        #expect(throws: ShaderGraphDiagnostic(code: .cycle, nodeID: "cycle")) { try graph.lowered() }
    }

    @Test func missingRequiredInputsAreRejected() {
        var graph = sprite()
        graph.nodes.append(.init(id: "add", operation: .add))
        #expect(throws: ShaderGraphDiagnostic(code: .missingInput, nodeID: "add", port: "a")) { try graph.lowered() }
    }

    @Test func deepSharedGraphsDoNotRecurseOrDuplicateInstructions() throws {
        var graph = sprite()
        graph.nodes.append(.init(id: "scalar", operation: .constant, value: [1]))
        var previous = "scalar"
        for index in 0..<4096 {
            let id = "add\(index)"
            graph.nodes.append(.init(id: id, operation: .add, inputs: ["a": .init(previous), "b": .init(previous)]))
            previous = id
        }
        graph.nodes[1].inputs["alpha"] = .init(previous)
        let program = try graph.lowered()
        #expect(program.instructions.count == graph.nodes.count)
        #expect(Set(program.instructions.map(\.nodeID)).count == program.instructions.count)
        #expect(program.instructions.last?.nodeID == "output")
    }

    @Test func parameterDefaultsAndReferencesAreChecked() throws {
        var graph = sprite()
        graph.nodes[0] = .init(id: "tint", operation: .parameter, type: .color, value: [1, 1, 1, 1], reference: "tint-parameter")
        #expect(try graph.lowered().instructions.first?.reference == "tint-parameter")
        graph.nodes[0].reference = ""
        #expect(throws: ShaderGraphDiagnostic(code: .invalidReference, nodeID: "tint")) { try graph.lowered() }
        graph.nodes[0] = .init(id: "tint", operation: .constant, type: .bool, value: [2])
        #expect(throws: ShaderGraphDiagnostic(code: .invalidLiteral, nodeID: "tint")) { try graph.lowered() }
    }

    @Test(arguments: [ShaderGraph.Target.sprite, .pbrSurface])
    func unconnectedOutputsLeaveDefaultsToTheTarget(target: ShaderGraph.Target) throws {
        let graph = ShaderGraph(target: target, output: "output", nodes: [.init(id: "output", operation: .output)])
        let program = try graph.lowered()
        #expect(program.target == target)
        #expect(program.instructions.count == 1)
        #expect(program.instructions[0].type == nil)
        #expect(program.instructions[0].inputs.isEmpty)
    }

    @Test func textureParametersCanFeedSamplingNodes() throws {
        var graph = sprite()
        graph.nodes += [
            .init(id: "texture", operation: .parameter, type: .texture2D, reference: "image-parameter"),
            .init(id: "uv", operation: .uv, type: .vector2),
            .init(id: "sample", operation: .sampleTexture, type: .vector4, inputs: ["texture": .init("texture"), "uv": .init("uv")])
        ]
        graph.nodes[1].inputs["color"] = .init("sample", port: "color")
        let program = try graph.lowered()
        #expect(program.instructions.first { $0.nodeID == "texture" }?.type == .texture2D)
        #expect(program.instructions.first { $0.nodeID == "sample" }?.inputs["texture"]?.conversion == .identity)
    }

    @Test func sharedParametersMustAgreeOnTypeAndDefault() throws {
        var graph = sprite()
        graph.nodes[0].kind = ShaderGraph.Operation.parameter.rawValue
        graph.nodes[0].reference = "shared"
        var alias = graph.nodes[0]
        alias.id = "alias"
        graph.nodes.append(alias)
        _ = try graph.lowered()
        graph.nodes[2].value[0] = 0
        #expect(throws: ShaderGraphDiagnostic(code: .conflictingParameter, nodeID: "tint", expected: .color, actual: .color)) { try graph.lowered() }
        graph.nodes[2].type = .vector4
        #expect(throws: ShaderGraphDiagnostic(code: .conflictingParameter, nodeID: "tint", expected: .vector4, actual: .color)) { try graph.lowered() }
    }
}
