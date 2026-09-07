@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
import AdaInput
@_spi(Internal) import AdaUI
import AdaUtils
import Foundation
import Math
import Testing

@MainActor
@Suite(.serialized)
struct EditorFileTemplateMenuTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            let app = AppWorlds(main: World(name: "EditorFileTemplateMenuTests"))
            RenderWorldPlugin().setup(in: app)
        }
    }

    @Test("tree context menu creates every template beside the clicked file")
    func contextMenuCreatesTemplates() throws {
        let root = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = makeViewModel(root: root)
        let container = makeSidebar(model)
        var presentation: ContextMenuPresentation?
        let previousPresenter = ContextMenuPresentationCenter.present
        ContextMenuPresentationCenter.present = { presentation = $0 }
        defer { ContextMenuPresentationCenter.present = previousPresenter }

        for kind in EditorNewFileKind.allCases {
            let row = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.ProjectTree.Existing.swift"))
            container.onMouseEvent(MouseEvent(
                window: RID(),
                button: .right,
                mousePosition: Point(row.absoluteFrame.midX, row.absoluteFrame.midY),
                phase: .began,
                modifierKeys: [],
                time: 0
            ))
            let menu = try #require(presentation?.items.first)
            #expect(menu.title == "New")
            #expect(menu.submenu.map(\.title) == EditorNewFileKind.allCases.map(\.title))
            let template = try #require(menu.submenu.first { $0.title == kind.title })
            let createAction = try #require(template.action)
            createAction()
            #expect(model.isNewFileKindPreselected)
            #expect(model.newFileKind == kind)
            #expect(model.newFileDestinationRelativePath == "Sources/Game")
            model.newFileName = "Created-\(kind.rawValue)"
            let expectedPath = "Sources/Game/Created-\(kind.rawValue).\(kind.fileExtension)"
            #expect(model.newFilePreviewPath == expectedPath)
            #expect(model.createNewFile())
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(expectedPath).path))
            #expect(model.workbench.activeDocument?.relativePath == expectedPath)
            container.layoutIfNeeded()
        }

        let background = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.ProjectTree.Background"))
        container.onMouseEvent(MouseEvent(
            window: RID(),
            button: .right,
            mousePosition: Point(background.absoluteFrame.minX + 5, background.absoluteFrame.maxY - 5),
            phase: .began,
            modifierKeys: [],
            time: 1
        ))
        let action = try #require(presentation?.items.first?.submenu.first?.action)
        action()
        #expect(model.newFileDestinationRelativePath.isEmpty)
        model.newFileName = "RootScene"
        #expect(model.createNewFile())
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("RootScene.ascn").path))
    }

    @Test("New button offers templates before opening the name dialog")
    func toolbarSelectsTemplateAndDismissesMenu() async throws {
        let root = try makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = makeViewModel(root: root)
        let folder = try #require(model.projectSidebar.items.first { $0.relativePath == "Sources/Game" })
        model.projectSidebar.select(folder)
        let container = makeSidebar(model)

        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.ProjectTree.NewFile"))
        container.layoutIfNeeded()
        #expect(!model.isNewFileDialogPresented)
        for kind in EditorNewFileKind.allCases {
            #expect(!container.uiFindNodes(matching: .accessibilityIdentifier("AdaEditor.ProjectTree.New.\(kind.rawValue)")).isEmpty)
        }
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.ProjectTree.New.script"))
        container.layoutIfNeeded()
        #expect(model.newFileKind == .script)
        #expect(model.newFileDestinationRelativePath == "Sources/Game")
        #expect(model.isNewFileKindPreselected)
        #expect(container.uiFindNodes(matching: .accessibilityIdentifier("AdaEditor.ProjectTree.New.Menu")).isEmpty)

        let dialog = UIContainerView(rootView: EditorNewFileDialog(viewModel: model))
        dialog.frame = Rect(x: 0, y: 0, width: 600, height: 700)
        dialog.bounds.size = dialog.frame.size
        dialog.layoutIfNeeded()
        #expect(!dialog.uiFindNodes(matching: .accessibilityIdentifier("AdaEditor.NewFile.Name")).isEmpty)
        #expect(dialog.uiFindNodes(matching: .accessibilityIdentifier("AdaEditor.NewFile.Kind.scene")).isEmpty)
        model.newFileName = "Movement"
        try await waitForPreview(in: dialog)
        _ = try dialog.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.NewFile.Create"))
        #expect(!model.isNewFileDialogPresented)
        let source = try String(contentsOf: root.appendingPathComponent("Sources/Game/Movement.ada"), encoding: .utf8)
        #expect(source.contains("class MovementSystem"))
        model.presentNewFileDialog()
        #expect(!model.isNewFileKindPreselected)
        let reopenedDialog = UIContainerView(rootView: EditorNewFileDialog(viewModel: model))
        reopenedDialog.frame = dialog.frame
        reopenedDialog.bounds.size = dialog.bounds.size
        reopenedDialog.layoutIfNeeded()
        #expect(!reopenedDialog.uiFindNodes(matching: .accessibilityIdentifier("AdaEditor.NewFile.Kind.scene")).isEmpty)
        _ = try reopenedDialog.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.NewFile.Cancel"))
        #expect(!model.isNewFileDialogPresented)

        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.ProjectTree.NewFile"))
        container.layoutIfNeeded()
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.ProjectTree.New.Dismiss"))
        container.layoutIfNeeded()
        #expect(container.uiFindNodes(matching: .accessibilityIdentifier("AdaEditor.ProjectTree.New.Menu")).isEmpty)
    }

    private func waitForPreview<Content: View>(in dialog: UIContainerView<Content>) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        let preview = UINodeSelector.accessibilityIdentifier("AdaEditor.NewFile.Preview")
        while ContinuousClock.now < deadline {
            dialog.update(1.0 / 60.0)
            dialog.layoutIfNeeded()
            if !dialog.uiFindNodes(matching: preview).isEmpty {
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!dialog.uiFindNodes(matching: preview).isEmpty, "The dialog should reflect the entered file name")
    }

    private func makeViewModel(root: URL) -> EditorViewModel {
        EditorViewModel(
            project: EditorProjectReference(name: "Templates", path: root.path),
            sourceControlService: GitRepositoryService(processRunner: TemplateMenuGitRunner())
        )
    }

    private func makeSidebar(_ model: EditorViewModel) -> UIContainerView<some View> {
        let container = UIContainerView(rootView: EditorProjectSidebar(
            viewModel: model.projectSidebar,
            projectRootItem: model.projectRootSidebarItem,
            onOpenItem: { model.openProjectItem($0) },
            onOpenRawItem: { model.openProjectItemAsRaw($0) },
            onNewFile: { model.presentNewFileDialog(kind: $0) },
            onImportAssets: {},
            onRevealItem: { _ in },
            onOpenInDefaultApplication: { _ in },
            onOpenInTerminal: { _ in },
            onFindInFolder: { _ in },
            onFindInProjectRoot: {},
            onCopyPath: { _, _ in },
            onDeleteItem: { _ in }
        ))
        container.frame = Rect(x: 0, y: 0, width: 320, height: 600)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        return container
    }

    private func makeProjectDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TemplateMenu-\(UUID().uuidString)")
        let sources = root.appendingPathComponent("Sources/Game")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        try "import AdaEngine\n".write(to: sources.appendingPathComponent("Existing.swift"), atomically: true, encoding: .utf8)
        return root
    }
}

// These filesystem/UI fixtures have no Git repository; avoid unrelated background processes.
private struct TemplateMenuGitRunner: EditorProcessRunning {
    func run(_ command: EditorProcessCommand) async -> EditorProcessResult {
        EditorProcessResult(command: command, exitCode: 128, standardOutput: "", standardError: "Not a git repository")
    }

    func cancelAll() async {}
}
