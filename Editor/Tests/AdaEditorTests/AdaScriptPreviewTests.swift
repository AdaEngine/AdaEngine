@testable import AdaEditor
import Foundation
import Testing

@Suite("Ada Script previews")
struct AdaScriptPreviewTests {
    @Test("editor view model loads a selected Ada Script preview")
    @MainActor
    func editorViewModelLoadsPreview() async throws {
        let fileManager = FileManager.default
        let projectURL = fileManager.temporaryDirectory
            .appendingPathComponent("AdaEditorAdaScriptPreviewIntegration-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: projectURL) }
        let sourceRoot = projectURL.appendingPathComponent("Sources/Game/Views", isDirectory: true)
        try fileManager.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        let source = "@previewable(title: \"HUD Preview\") @view class HUDView { func body() { Text(\"Preview\"); } }"
        let sourceURL = sourceRoot.appendingPathComponent("HUD.ada")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        let document = EditorTextDocument(
            id: "hud",
            title: "HUD.ada",
            relativePath: "Sources/Game/Views/HUD.ada",
            absolutePath: sourceURL.path,
            language: .ada,
            content: source,
            errorMessage: nil
        )
        let workbench = EditorWorkbenchViewModel()
        workbench.open(.text(document))
        let viewModel = EditorViewModel(
            project: EditorProjectReference(name: "Game", path: projectURL.path),
            workbench: workbench,
            packageModel: packageModel()
        )

        viewModel.refreshPreviewForActiveDocument()
        for _ in 0..<100 {
            if case .loaded(let declaration, _) = workbench.previewStatus {
                #expect(declaration.id == "HUDView")
                #expect(declaration.title == "HUD Preview")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        if case .failed(_, let message, _) = workbench.previewStatus {
            Issue.record("AdaEditor preview failed: \(message) \(viewModel.outputLines.map(\.text).joined(separator: " | "))")
        } else {
            Issue.record("AdaEditor did not load the Ada Script preview")
        }
    }

    @Test("scanner finds view declarations")
    func scannerFindsViews() {
        let declarations = EditorPreviewScanner.declarations(
            in: """
            @previewable(title: "HUD Preview")
            @view(id: "game.hud", title: "HUD")
            class HUDView {
                func body() { Text("Score"); }
            }

            @view
            class RuntimeOnlyView {
                func body() { Text("Hidden"); }
            }

            @system
            class UpdateSystem {
                func update(context) {}
            }
            """,
            language: .ada
        )

        #expect(declarations == [
            EditorPreviewDeclaration(
                id: "game.hud",
                title: "HUD Preview",
                typeName: "HUDView",
                line: 3,
                kind: .adaScript
            )
        ])
    }

    @Test("builder collects target sources and keeps unsaved content")
    func builderCollectsTargetSources() async throws {
        let fileManager = FileManager.default
        let projectURL = fileManager.temporaryDirectory
            .appendingPathComponent("AdaEditorAdaScriptPreview-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: projectURL) }

        let sourceRoot = projectURL.appendingPathComponent("Sources/Game", isDirectory: true)
        let viewsRoot = sourceRoot.appendingPathComponent("Views", isDirectory: true)
        try fileManager.createDirectory(at: viewsRoot, withIntermediateDirectories: true)
        let activeURL = viewsRoot.appendingPathComponent("HUD.ada")
        try "stale".write(to: activeURL, atomically: true, encoding: .utf8)
        try "func helper() { return 7; }".write(
            to: sourceRoot.appendingPathComponent("Shared.ada"),
            atomically: true,
            encoding: .utf8
        )

        let model = packageModel()
        let content = "@previewable @view class HUDView { func body() { Text(\"Unsaved\"); } }"
        let document = EditorTextDocument(
            id: "hud",
            title: "HUD.ada",
            relativePath: "Sources/Game/Views/HUD.ada",
            absolutePath: activeURL.path,
            language: .ada,
            content: content,
            errorMessage: nil
        )
        let declaration = EditorPreviewDeclaration(
            id: "HUDView",
            title: "HUDView",
            typeName: "HUDView",
            line: 1,
            kind: .adaScript
        )

        let artifact = try await EditorAdaScriptPreviewBuilder().build(
            EditorPreviewBuildRequest(
                projectURL: projectURL,
                document: document,
                packageModel: model,
                declaration: declaration
            )
        )

        #expect(artifact.identifier == "HUDView")
        #expect(artifact.sources.map(\.path) == ["Shared.ada", "Views/HUD.ada"])
        #expect(artifact.sources.last?.source == content)
    }

    private func packageModel() -> SwiftPackageModel {
        SwiftPackageModel(
            name: "Game",
            products: [],
            targets: [
                SwiftPackageTarget(
                    name: "Game",
                    type: "executable",
                    path: "Sources/Game",
                    sources: ["Views/HUD.ada", "Shared.ada"],
                    targetDependencies: [],
                    productDependencies: ["AdaEngine"]
                )
            ],
            dependencies: []
        )
    }
}
