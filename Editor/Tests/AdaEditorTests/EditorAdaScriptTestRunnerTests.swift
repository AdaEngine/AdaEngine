import Foundation
import MCP
import Testing

@testable import AdaEditor

@Suite("AdaScript test runner", .serialized)
struct EditorAdaScriptTestRunnerTests {
    private static let passing = """
    class Counter {
        var value = 0;
        func bump() { value += 1; }
    }
    @test("bumps once")
    func bumpsOnce() {
        var c = Counter();
        c.bump();
        expectEqual(c.value, 1);
    }
    """

    private static let failing = """
    @test("adds")
    func adds() {
        expectEqual(1 + 1, 3);
    }
    @test("fine")
    func fine() { expect(true); }
    """

    private static let spinning = """
    @test("spins")
    func spins() {
        var i = 0;
        while (true) { i += 1; }
    }
    @test("quick")
    func quick() { expect(true); }
    """

    @Test("A passing project reports every test as passed")
    func passes() throws {
        let root = try makeProject(["Sources/Main.ada": Self.passing, "Tests/More.ada": "@test\nfunc more() { expect(true); }"])
        defer { try? FileManager.default.removeItem(at: root) }
        var streamed: [String] = []
        let outcomes = try EditorAdaScriptTestRunner().run(project: try loadProject(root), at: root, filter: nil) { streamed.append($0.name) }
        #expect(outcomes.map(\.passed) == [true, true])
        #expect(Set(outcomes.map(\.path)) == ["Sources/Main.ada", "Tests/More.ada"])
        #expect(Set(streamed) == Set(outcomes.map(\.name)))
    }

    @Test("A failing test carries its message with file, line and column")
    func failure() throws {
        let root = try makeProject(["Sources/Main.ada": Self.failing])
        defer { try? FileManager.default.removeItem(at: root) }
        let outcomes = try EditorAdaScriptTestRunner().run(project: try loadProject(root), at: root, filter: nil)
        let failed = try #require(outcomes.first { !$0.passed })
        #expect(failed.name == "adds")
        #expect(failed.diagnostics.first?.hasPrefix("Sources/Main.ada:3:") == true)
        #expect(failed.diagnostics.first?.contains("expected 3 but got 2") == true)
        #expect(outcomes.filter(\.passed).map(\.name) == ["fine"])
        #expect(EditorAdaScriptTestRunner.lines(for: failed).first?.hasPrefix("FAIL adds (Sources/Main.ada:2") == true)
    }

    @Test("The filter selects tests by name and an unmatched filter is reported")
    func filter() throws {
        let root = try makeProject(["Sources/Main.ada": Self.failing])
        defer { try? FileManager.default.removeItem(at: root) }
        let project = try loadProject(root)
        let outcomes = try EditorAdaScriptTestRunner().run(project: project, at: root, filter: "fine")
        #expect(outcomes.map(\.name) == ["fine"])
        #expect(throws: EditorAdaScriptTestError.noTests(filter: "missing")) {
            try EditorAdaScriptTestRunner().run(project: project, at: root, filter: "missing")
        }
    }

    @Test("A test that never finishes times out and later tests still run")
    func timeout() throws {
        let root = try makeProject(["Tests/Spin.ada": Self.spinning])
        defer { try? FileManager.default.removeItem(at: root) }
        let outcomes = try EditorAdaScriptTestRunner().run(project: try loadProject(root), at: root, filter: nil, testTimeout: .milliseconds(200))
        #expect(outcomes.map(\.passed) == [false, true])
        #expect(outcomes[0].diagnostics.contains { $0.contains("timed out") })
    }

    @Test("A project without tests is rejected, and a compile error is reported")
    func noTestsAndLoadErrors() throws {
        let empty = try makeProject(["Sources/Main.ada": "func helper() { return 1; }"])
        let broken = try makeProject(["Sources/Main.ada": "func broken( {"])
        defer {
            try? FileManager.default.removeItem(at: empty)
            try? FileManager.default.removeItem(at: broken)
        }
        let runner = EditorAdaScriptTestRunner()
        #expect(!runner.hasTests(project: try loadProject(empty), at: empty))
        #expect(throws: EditorAdaScriptTestError.noTests(filter: nil)) {
            try runner.run(project: try loadProject(empty), at: empty, filter: nil)
        }
        #expect(throws: EditorAdaScriptTestError.self) {
            try runner.run(project: try loadProject(broken), at: broken, filter: nil)
        }
    }

    @Test("editor.test.start runs an AdaScript project and editor.task.status reports the counts")
    @MainActor
    func toolRunsTests() async throws {
        let root = try makeProject(["Sources/Main.ada": Self.failing])
        defer { try? FileManager.default.removeItem(at: root) }
        let editor = EditorViewModel(project: EditorProjectReference(name: "Failing", path: root.path))
        EditorAgentMCPTools.shared.activate(editor)
        defer { EditorAgentMCPTools.shared.deactivate(editor) }

        let accepted = try #require(EditorAgentWorkspaceMCPTools.shared.handle(name: "editor.test.start", arguments: [:]))
        #expect(accepted.isError != true)
        for _ in 0..<500 where editor.workspaceTask != nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        let status = try payload(try #require(EditorAgentWorkspaceMCPTools.shared.handle(name: "editor.task.status", arguments: [:])))
        let tests = try #require(status["adaScriptTests"] as? [String: Any])
        #expect(tests["passed"] as? Int == 1)
        #expect(tests["failed"] as? Int == 1)
        #expect(tests["total"] as? Int == 2)
        #expect(tests["finished"] as? Bool == true)
        let output = editor.outputLines.map(\.text)
        #expect(output.contains { $0.hasPrefix("FAIL adds") })
        #expect(output.contains("1 passed, 1 failed, 2 total"))
        #expect(editor.workspaceStatus == .failed("1 passed, 1 failed, 2 total"))
    }

    @Test("editor.test.start refuses an AdaScript project that has no tests")
    @MainActor
    func toolRefusesProjectWithoutTests() throws {
        let root = try makeProject(["Sources/Main.ada": "func helper() { return 1; }"])
        defer { try? FileManager.default.removeItem(at: root) }
        let editor = EditorViewModel(project: EditorProjectReference(name: "Empty", path: root.path))
        EditorAgentMCPTools.shared.activate(editor)
        defer { EditorAgentMCPTools.shared.deactivate(editor) }
        let response = try #require(EditorAgentWorkspaceMCPTools.shared.handle(name: "editor.test.start", arguments: [:]))
        #expect(response.isError == true)
        guard case let .text(text, _, _) = response.content.first else {
            Issue.record("Expected a text refusal")
            return
        }
        #expect(text.contains("no AdaScript tests"))
        #expect(editor.workspaceTask == nil)
    }

    // MARK: Helpers

    private func makeProject(_ files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ada-test-runner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".ada"), withIntermediateDirectories: true)
        let metadata = """
        {"schemaVersion": 3, "project": {"name": "Sample"}, "build": {"system": "adascript", "targets": [], "includedFiles": [], "excludedFiles": []},
         "paths": {"sources": "Sources"}, "runtime": {"entry": {"startupSystem": "Sample"}, "moduleName": "Sample"}}
        """
        try metadata.write(to: root.appendingPathComponent(".ada/project.json"), atomically: true, encoding: .utf8)
        for (path, text) in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return root
    }

    private func loadProject(_ root: URL) throws -> AdaProject {
        try ProjectSystem.loadProject(at: root)
    }

    private func payload(_ result: CallTool.Result) throws -> [String: Any] {
        guard case let .text(text, _, _) = result.content.first else { return [:] }
        return try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }
}
