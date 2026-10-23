@testable import AdaShaderGraphBaker
import Foundation
import Testing

@Suite("Web export graph detection")
struct WebExportSupportTests {
    @Test func onlyGraphResourcesRequireTheHostBaker() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let scene = root.appendingPathComponent("Main.ascn")
        func write(_ object: Any) throws {
            try JSONSerialization.data(withJSONObject: object).write(to: scene)
        }
        try write(["entities": [["components": ["Sprite": ["size": [64, 64]]]]]])
        #expect(try !WebExportSupport.needsShaderGraphBaker(scene))
        #expect(try WebExportSupport.needsShaderGraphBaker(root.appendingPathComponent("Tint.shadergraph")))
        let reference = try JSONSerialization.data(withJSONObject: ["graphMaterial": ["path": "@res://missing.shadergraph"]])
        try write(["components": ["Sprite": reference.base64EncodedString()]])
        #expect(try WebExportSupport.needsShaderGraphBaker(scene))
        let inline: [String: Any] = ["graphMaterial": ["graph": ["target": "pbrSurface", "nodes": []]]]
        try write(inline)
        #expect(try WebExportSupport.needsShaderGraphBaker(scene))
        let model = root.appendingPathComponent("Model.gltf")
        try JSONSerialization.data(withJSONObject: inline).write(to: model)
        #expect(try WebExportSupport.needsShaderGraphBaker(model))
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ADAENGINE_SHADER_GRAPH_FAILING_TINT"] != nil))
    func largeStderrDoesNotBlockTheExportProcess() throws {
        let executable = try #require(ProcessInfo.processInfo.environment["ADAENGINE_SHADER_GRAPH_FAILING_TINT"])
        do {
            _ = try WebExportSupport.captureStandardOutput(executable: executable, arguments: [], workingDirectory: nil)
            Issue.record("The failing compiler should reject the export")
        } catch let error as WebExportSupport.CommandError {
            #expect(error.description.contains("stderr complete"))
            #expect(error.description.contains("17"))
        }
    }
}
