@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Math
import Testing

@Suite("Editor debugger panel")
@MainActor
struct EditorDebuggerPanelTests {
    @Test func tabsAndWatchActionsUseRealViewNodes() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            let worlds = AppWorlds(main: World(name: "DebuggerPanelTests"))
            RenderWorldPlugin().setup(in: worlds)
        }
        let debugger = EditorDebugger()
        let container = UIContainerView(rootView: EditorDebugPanel(debugger: debugger))
        container.frame = Rect(x: 0, y: 0, width: 760, height: 280)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let command = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Debug.Command"))
        #expect(command.absoluteFrame.width >= 100)
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Debug.Tab.Watches"))
        container.layoutIfNeeded()
        _ = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Debug.WatchExpression"))
        debugger.watchExpression = "player.position.x"
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Debug.AddWatch"))
        #expect(debugger.watches == ["player.position.x"])
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Debug.Tab.Console"))
        container.layoutIfNeeded()
        _ = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Debug.Command"))
    }
}
