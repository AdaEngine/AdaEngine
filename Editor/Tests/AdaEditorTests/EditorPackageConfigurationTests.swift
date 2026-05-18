import Foundation
import Testing

@Suite("AdaEditor package configuration")
struct EditorPackageConfigurationTests {
    @Test("editor package declares local AdaEngine and AdaMCP dependencies")
    func packageManifestDeclaresRequiredDependencies() throws {
        let editorRoot = try editorPackageRoot()
        let manifest = try String(contentsOf: editorRoot.appendingPathComponent("Package.swift"), encoding: .utf8)

        #expect(manifest.contains("name: \"AdaEditor\""))
        #expect(manifest.contains(".package(path: \"..\")"))
        #expect(manifest.contains("https://github.com/AdaEngine/AdaMCP"))
        #expect(manifest.contains("name: \"AdaEditor\""))
        #expect(manifest.contains(".product(name: \"AdaEngine\", package: \"AdaEngine\")"))
        #expect(manifest.contains(".product(name: \"AdaMCPCore\", package: \"AdaMCP\")"))
        #expect(manifest.contains(".copy(\"Assets\")"))
    }

    @Test("xcodegen project points at the local editor package")
    func xcodegenConfigurationUsesLocalPackage() throws {
        let editorRoot = try editorPackageRoot()
        let project = try String(contentsOf: editorRoot.appendingPathComponent("project.yml"), encoding: .utf8)

        #expect(project.contains("name: AdaEditor"))
        #expect(project.contains("AdaEditor:"))
        #expect(project.contains("path: ."))
        #expect(project.contains("product: AdaEditor"))
    }

    private func editorPackageRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Editor" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                throw CocoaError(.fileNoSuchFile)
            }
            url = parent
        }
        return url
    }
}
