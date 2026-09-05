@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Foundation
import Math
import Testing

@Suite("AdaScript project runtime", .serialized)
struct AdaScriptProjectRuntimeTests {
    @Test("Run opens an AdaScript project in a separate window")
    @MainActor
    func runOpensSeparateWindow() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            let app = AppWorlds(main: World(name: "AdaScriptRuntimeTests"))
            RenderWorldPlugin().setup(in: app)
        }

        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("AdaScriptRuntime-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: rootURL) }
        let project = try EditorProjectStore(
            storageURL: rootURL.appendingPathComponent("projects.json")
        ).createProject(named: "RuntimeGame", at: rootURL, template: .adaScript)

        let previousManager = UIWindowManager.shared
        let windowManager = AdaScriptRuntimeTestWindowManager()
        UIWindowManager.setShared(windowManager)
        defer {
            if let previousManager {
                UIWindowManager.setShared(previousManager)
            }
        }

        let viewModel = EditorViewModel(project: project)
        viewModel.runSelectedTarget()

        #expect(windowManager.shownWindowCount == 1)
        #expect(windowManager.windows.count == 1)
        #expect(viewModel.workspaceStatus == .running("Run RuntimeGame"))
        #expect(viewModel.outputLines.contains { $0.text == "Running AdaScript project RuntimeGame in a separate window." })

        viewModel.cancelWorkspaceCommand()

        #expect(windowManager.closedWindowCount == 1)
        #expect(viewModel.workspaceStatus == .ready)
    }

    @Test("Preview loads for an AdaScript project without SwiftPM")
    @MainActor
    func previewLoadsWithoutSwiftPM() async throws {
        let fileManager = FileManager.default
        let projectURL = fileManager.temporaryDirectory
            .appendingPathComponent("AdaScriptPreview-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: projectURL) }
        let sourceRoot = projectURL.appendingPathComponent("Sources/Game/Views", isDirectory: true)
        try fileManager.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        let source = "@previewable(title: \"HUD Preview\") @view class HUDView { func body() { Text(\"Preview\"); } }"
        let sourceURL = sourceRoot.appendingPathComponent("HUD.ada")
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)

        var project = ProjectSystem.defaultProject(projectName: "Game", buildSystem: .adaScript)
        project.paths.sources = "Sources/Game"
        try ProjectSystem.saveProject(project, at: projectURL)
        let document = EditorTextDocument(
            id: "hud",
            title: "HUD.ada",
            relativePath: "Sources/Game/Views/HUD.ada",
            absolutePath: sourceURL.path,
            language: .ada,
            content: source,
            lastSavedContent: source
        )
        let workbench = EditorWorkbenchViewModel()
        workbench.open(.text(document))
        let viewModel = EditorViewModel(
            project: EditorProjectReference(name: "Game", path: projectURL.path),
            workbench: workbench
        )

        viewModel.refreshPreviewForActiveDocument()
        for _ in 0..<100 {
            if case .loaded(let declaration, _) = workbench.previewStatus {
                #expect(declaration.id == "HUDView")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }

        Issue.record("AdaEditor did not load the AdaScript preview: \(viewModel.outputLines.map(\.text).joined(separator: " | "))")
    }
}

@MainActor
private final class AdaScriptRuntimeTestWindowManager: UIWindowManager {
    private(set) var closedWindowCount = 0
    private(set) var shownWindowCount = 0

    override func showWindow(_ window: UIWindow, isFocused: Bool) {
        shownWindowCount += 1
        if isFocused {
            setActiveWindow(window)
        }
    }

    override func closeWindow(_ window: UIWindow) {
        closedWindowCount += 1
    }

    override func setWindowMode(_ window: UIWindow, mode: UIWindow.Mode) {}
    override func setMinimumSize(_ size: Size, for window: UIWindow) {}
    override func resizeWindow(_ window: UIWindow, size: Size) {}
    override func getScreen(for window: UIWindow) -> Screen? { nil }
}
