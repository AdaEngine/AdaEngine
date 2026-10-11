@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Foundation
import Testing

@testable import AdaEditor

@Suite("VR editor dock", .serialized)
@MainActor
struct EditorVRDockTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World()))
        }
    }

    @Test("Dock taps select tools and open panels without editing the scene or camera")
    func dockControls() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = EditorVRWorkspace(store: EditorProjectStore(storageURL: root.appendingPathComponent("recents.json")))
        try workspace.createStarter(at: root)
        let baseline = workspace.document?.content
        let world = World()
        workspace.attachWorld(world)
        var opened: EditorVRPanel?
        let container = UIContainerView(
            rootView: EditorVRDock(
                workspace: workspace,
                togglePanel: { opened = $0 },
                focusSelection: {}
            ).environment(\.theme, .adaEditor)
        )
        container.frame = Rect(x: 0, y: 0, width: 824, height: 132)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let move = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.VR.Tool.Move"))
        #expect(move.absoluteFrame.width >= 56)
        #expect(move.absoluteFrame.height >= 56)
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.VR.Tool.Rotate"))
        #expect(workspace.activeTool == .rotate)
        #expect(world.getResource(SpatialInteractionSettings.self)?.mode == .rotate)
        #expect(workspace.document?.content == baseline)
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.VR.Panel.hierarchy"))
        #expect(opened == .hierarchy)
        let selected = workspace.viewport.selectedEditorID
        workspace.setPanel(.hierarchy, visible: true)
        workspace.setPanel(.hierarchy, visible: false)
        #expect(workspace.viewport.selectedEditorID == selected)
        #expect(workspace.document?.content == baseline)
        #expect(world.getEntities().allSatisfy { $0.components[Camera.self] == nil })
    }

    @Test("Assets, Save and Undo dock actions operate on a real scene document")
    func assetSaveUndo() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = EditorVRWorkspace(store: EditorProjectStore(storageURL: root.appendingPathComponent("recents.json")))
        try workspace.createStarter(at: root)
        let before = try #require(workspace.document)
        let assets = UIContainerView(rootView: EditorVRAssetsPanel(workspace: workspace).environment(\.theme, .adaEditor))
        assets.frame = Rect(x: 0, y: 0, width: 430, height: 380)
        assets.bounds.size = assets.frame.size
        assets.layoutIfNeeded()
        _ = try assets.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.VR.Add.Sphere"))
        #expect(workspace.document?.sceneModel?.entities.count == (before.sceneModel?.entities.count ?? 0) + 1)
        #expect(workspace.canSave)
        #expect(workspace.canUndo)
        let dock = UIContainerView(rootView: EditorVRDock(workspace: workspace, togglePanel: { _ in }, focusSelection: {}).environment(\.theme, .adaEditor))
        dock.frame = Rect(x: 0, y: 0, width: 824, height: 132)
        dock.bounds.size = dock.frame.size
        dock.layoutIfNeeded()
        _ = try dock.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.VR.Save"))
        #expect(workspace.saveStatus == "Saved")
        let path = try #require(workspace.document?.absolutePath)
        #expect(try String(contentsOfFile: path, encoding: .utf8) == workspace.document?.content)
        _ = try dock.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.VR.Undo"))
        #expect(workspace.document?.sceneModel?.entities == before.sceneModel?.entities)
        #expect(workspace.canRedo)
        #expect(workspace.saveStatus == "Modified")
        // Wait for the hit-tested button, including inherited enabled state and final layout.
        let redo = UINodeSelector.accessibilityIdentifier("AdaEditor.VR.Redo")
        var ready = false
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(10))
            dock.update(1.0 / 60.0)
            dock.layoutIfNeeded()
            let node = try dock.uiNode(matching: redo)
            let hit = dock.uiHitTest(at: Point(x: node.absoluteFrame.midX, y: node.absoluteFrame.midY))
            ready = hit?.node.canBecomeFocused == true && hit?.path.contains(where: { $0.accessibilityIdentifier == "AdaEditor.VR.Redo" }) == true
            if ready { break }
        }
        try #require(ready)
        _ = try dock.uiTapNode(matching: redo)
        #expect(workspace.document?.isDirty == false)
    }

    @Test("A held spatial edit blocks conflicting tool changes")
    func lockedToolDuringGrab() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = EditorVRWorkspace(store: EditorProjectStore(storageURL: root.appendingPathComponent("recents.json")))
        try workspace.createStarter(at: root)
        workspace.isManipulating = true
        workspace.setTool(.scale)
        #expect(workspace.activeTool == .translate)
        #expect(!workspace.canSave)
        #expect(!workspace.canEdit)
    }
}
