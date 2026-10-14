@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Testing

@testable import AdaEditor

@Suite("Settings window layout", .serialized)
@MainActor
struct EditorSettingsLayoutTests {
    @Test("Cloud account content follows the window width after resizing")
    func cloudAccountContentFollowsWindowWidth() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "SettingsWindowLayout")))
        }

        let model = EditorSettingsWindowViewModel(editorViewModel: nil, selectedSection: .general)
        let container = UIContainerView(rootView: EditorSettingsWindowView(viewModel: model).theme(.adaEditor))

        container.frame = Rect(x: 0, y: 0, width: 760, height: 680)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let compactCard = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Cloud.AccountCard"))
        let compactWidth = compactCard.absoluteFrame.width

        container.frame = Rect(x: 0, y: 0, width: 1120, height: 680)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let expandedCard = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Cloud.AccountCard"))

        #expect(expandedCard.absoluteFrame.width == compactWidth + 360)
        #expect(expandedCard.calculateVisibleFrame().width == expandedCard.absoluteFrame.width)
    }
}
