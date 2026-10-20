@_spi(AdaEngine) import AdaEngine
@testable import AdaEditor
import Foundation
import Testing

@MainActor
@Suite("Shader Graph documents")
struct EditorShaderGraphModelTests {
    private func fixture() throws -> (URL, EditorShaderGraphModel) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).shadergraph")
        let graph = ShaderGraph(target: .sprite, output: "output", nodes: [
            .init(id: "a", operation: .constant, value: [1]),
            .init(id: "b", operation: .constant, value: [0.5]),
            .init(id: "sum", operation: .add, inputs: ["a": .init("a"), "b": .init("b")]),
            .init(id: "output", operation: .output, inputs: ["alpha": .init("sum")])
        ])
        try JSONEncoder().encode(graph).write(to: url)
        return (url, EditorShaderGraphModel(url: url))
    }

    @Test func dragCommitsOneUndoAndNeverChangesShaderRevision() throws {
        let (url, model) = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let revision = model.semanticRevision
        model.selection = ["a"]
        model.beginTransaction()
        model.moveNode("a", to: .init(x: 10, y: 30))
        model.moveNode("a", to: .init(x: 40, y: 90))
        model.endTransaction()
        #expect(model.isDirty)
        #expect(model.canUndo)
        #expect(model.semanticRevision == revision)
        model.undo()
        #expect(!model.canUndo)
        #expect(!model.isDirty)
        #expect(model.selection == ["a"])
        #expect(model.graph?.layout["a"] == nil)
        model.redo()
        #expect(model.graph?.layout["a"] == .init(x: 40, y: 90))
        #expect(model.save())
        let reopened = EditorShaderGraphModel(url: url)
        #expect(reopened.graph == model.graph)
        #expect(!reopened.isDirty)
    }

    @Test func rejectedWiresHaveNoUndoAndValidWiresSurviveReopen() throws {
        let (url, model) = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(!model.connect(.init("sum"), to: "sum", port: "a"))
        #expect(!model.connect(.init("a"), to: "output", port: "missing"))
        #expect(!model.canUndo)
        #expect(model.connect(.init("a"), to: "output", port: "alpha"))
        #expect(model.validation == nil)
        #expect(model.save())
        #expect(EditorShaderGraphModel(url: url).graph?.nodes.last?.inputs["alpha"] == .init("a"))
        model.undo()
        #expect(model.graph?.nodes.last?.inputs["alpha"] == .init("sum"))
    }

    @Test func externalEditsAndFutureVersionsAreNeverOverwritten() throws {
        let (url, model) = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        model.editNode("a") { $0.value = [2] }
        let foreign = Data(#"{"version":999,"futureSchema":true}"#.utf8)
        try foreign.write(to: url)
        #expect(!model.save())
        #expect(model.issue as? EditorShaderGraphFileError == .changedOnDisk)
        #expect(try Data(contentsOf: url) == foreign)
        let unsupported = EditorShaderGraphModel(url: url)
        #expect(unsupported.isReadOnly)
        #expect(unsupported.graph == nil)
        #expect(!unsupported.save())
        #expect(try Data(contentsOf: url) == foreign)
    }

    @Test func connectionPreflightAllowsIntermediateIncompleteNodes() throws {
        let (url, model) = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        model.editNode("sum") { $0.inputs = [:] }
        #expect(model.validation?.code == .missingInput)
        #expect(model.connect(.init("a"), to: "sum", port: "a"))
        #expect(model.connect(.init("b"), to: "sum", port: "b"))
        #expect(model.validation == nil)
    }
}
