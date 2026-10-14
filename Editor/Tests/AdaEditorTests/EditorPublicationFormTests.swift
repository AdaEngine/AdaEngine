@_spi(AdaEngine) import AdaEngine
@_spi(Internal) @testable import AdaUI
import Math
import Testing

@testable import AdaEditor

@MainActor
@Suite("Publication form layout", .serialized)
struct EditorPublicationFormTests {
    @Test(arguments: [Float(375), 867], [Float(360), 635])
    func actionsStayVisibleOutsideTheScrollView(width: Float, height: Float) throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "PublicationFormTests")))
        }
        let state = PublicationFormState()
        let container = UIContainerView(rootView: EditorPublicationForm(
            title: Binding(get: { state.title }, set: { state.title = $0 }),
            description: Binding(get: { state.description }, set: { state.description = $0 }),
            cover: nil,
            screenshots: [],
            busy: false,
            message: "",
            primaryTitle: "Sign in to continue",
            primaryEnabled: true,
            footerCaption: "Your draft stays saved on this device.",
            close: { state.closes += 1 },
            chooseCover: {},
            removeCover: {},
            addScreenshots: {},
            removeScreenshot: { _ in },
            primaryAction: { state.primaryActions += 1 }
        ).environment(\.theme, .adaEditor))
        container.frame = Rect(x: 0, y: 0, width: width, height: height)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let close = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Mobile.Publish.Close"))
        let action = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Mobile.Publish.Submit"))
        let scroll = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Mobile.Publish.Scroll"))
        #expect(close.absoluteFrame.minY >= 0)
        #expect(close.absoluteFrame.maxY <= scroll.absoluteFrame.minY)
        #expect(action.absoluteFrame.minY >= scroll.absoluteFrame.maxY)
        #expect(action.absoluteFrame.maxY <= height)
        #expect(action.absoluteFrame.maxY >= height - 20)
        #expect(action.absoluteFrame.minX >= 0 && action.absoluteFrame.maxX <= width)
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Mobile.Publish.Submit"))
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Mobile.Publish.Close"))
        #expect(state.primaryActions == 1)
        #expect(state.closes == 1)
    }
}

@MainActor
private final class PublicationFormState {
    var title = "New Game 1"
    var description = ""
    var closes = 0
    var primaryActions = 0
}
