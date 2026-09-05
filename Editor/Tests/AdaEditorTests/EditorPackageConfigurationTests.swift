import Foundation
import Testing

@Suite("AdaEditor package configuration")
struct EditorPackageConfigurationTests {
    @Test("editor package declares local AdaEngine dependency")
    func packageManifestDeclaresRequiredDependencies() throws {
        let editorRoot = try editorPackageRoot()
        let manifest = try String(contentsOf: editorRoot.appendingPathComponent("Package.swift"), encoding: .utf8)

        #expect(manifest.contains("name: \"AdaEditor\""))
        #expect(manifest.contains(".package(name: \"AdaEngine\", path: \"..\")"))
        #expect(manifest.contains("name: \"AdaEditor\""))
        #expect(manifest.contains(".product(name: \"AdaEngine\", package: \"AdaEngine\")"))
        #expect(manifest.contains(".product(name: \"AdaScriptCompilerCore\", package: \"AdaEngine\")"))
        #expect(manifest.contains(".copy(\"Assets\")"))
    }

    @Test("iPad app registers portable projects, Files access, resizable scenes, and a launch screen")
    func iPadBundleDeclaresDocumentRuntimeCapabilities() throws {
        let editorRoot = try editorPackageRoot()
        let data = try Data(contentsOf: editorRoot.appendingPathComponent("Sources/AdaEditor/Platforms/iOS/Info.plist"))
        let value = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let exportedTypes = try #require(value["UTExportedTypeDeclarations"] as? [[String: Any]])
        let projectType = try #require(exportedTypes.first)
        let tags = try #require(projectType["UTTypeTagSpecification"] as? [String: Any])
        let sceneManifest = try #require(value["UIApplicationSceneManifest"] as? [String: Any])

        #expect(projectType["UTTypeIdentifier"] as? String == "org.adaengine.project")
        #expect(tags["public.filename-extension"] as? [String] == ["adaproject"])
        #expect(value["LSSupportsOpeningDocumentsInPlace"] as? Bool == true)
        #expect(value["UISupportsDocumentBrowser"] as? Bool == true)
        #expect(sceneManifest["UIApplicationSupportsMultipleScenes"] as? Bool == true)
        #expect(value["UILaunchScreen"] as? [String: Any] != nil)
    }

    @Test("xcodegen project points at the local editor package")
    func xcodegenConfigurationUsesLocalPackage() throws {
        let editorRoot = try editorPackageRoot()
        let project = try String(contentsOf: editorRoot.appendingPathComponent("project.yml"), encoding: .utf8)

        #expect(project.contains("name: AdaEditor"))
        #expect(project.contains("AdaEditor:"))
        #expect(project.contains("path: ."))
        #expect(!project.contains("AdaEditorHost"))
        #expect(!project.contains("type: tool"))
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
