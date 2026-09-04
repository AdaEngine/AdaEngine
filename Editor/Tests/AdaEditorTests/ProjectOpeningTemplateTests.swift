@testable import AdaEditor
import Foundation
import Testing

@Suite("Project opening templates")
struct ProjectOpeningTemplateTests {
    @Test("Ada Script template keeps Swift in a generated bootstrap and creates an editable script")
    func createAdaScriptProject() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorAdaScriptProject-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let store = EditorProjectStore(
            storageURL: rootURL.appendingPathComponent("projects.json"),
            adaEnginePackageURL: EditorProjectStore.defaultAdaEnginePackageURL()
        )
        let reference = try store.createProject(named: "Script Game", at: rootURL, template: .adaScript)
        let targetURL = URL(fileURLWithPath: reference.path, isDirectory: true)
            .appendingPathComponent("Sources/Script_Game", isDirectory: true)

        #expect(FileManager.default.fileExists(atPath: targetURL.appendingPathComponent("AdaRuntimeBootstrap.swift").path))
        #expect(!FileManager.default.fileExists(atPath: targetURL.appendingPathComponent("main.swift").path))
        let script = try String(contentsOf: targetURL.appendingPathComponent("Main.ada"), encoding: .utf8)
        #expect(script.contains("@view"))
        #expect(script.contains("func body()"))
        #expect(script.contains("@system"))
        #expect(script.contains("func update(context)"))
    }

    @Test("launcher exposes project, template, and sample sections with both language templates")
    func projectOpeningSectionsAndTemplates() {
        #expect(ProjectOpeningSection.allCases == [.projects, .templates, .samples])
        #expect(EditorProjectTemplate.allCases == [.adaScript, .adaScriptWithSwift])
        #expect(EditorProjectTemplate.adaScript.displayName == "Ada Script")
        #expect(EditorProjectTemplate.adaScriptWithSwift.displayName == "Ada Script + Swift")
    }
}
