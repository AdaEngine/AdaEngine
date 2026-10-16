@testable import AdaPlatform
@testable import AdaUI
import AdaUtils
import Math
import Testing

@MainActor
@Suite("Window caption input regions")
struct WindowCaptionRegionTests {
    init() async throws { try Application.prepareForTest() }

    @Test("Caption controls retain their native hit regions")
    func captionControls() throws {
        let tester = ViewTester {
            VStack(spacing: 0) {
                WindowCaptionControls()
                    .environment(\.windowCaption, WindowCaptionPresentation(isVisible: true))
                    .frame(height: 32)
                Button("Body control") {}.frame(height: 100)
            }.frame(width: 640, height: 400, alignment: .topLeading)
        }.setSize(Size(width: 640, height: 400)).performLayout()
        let window = UIWindow(configuration: .init())
        window.addSubview(tester.containerView)
        tester.performLayout()
        let caption = tester.containerView.windowCaptionInputRegions(height: 32, window: window)
        let maximize = try #require(tester.findNodeByAccessibilityIdentifier("AdaUI.Caption.Maximize"))
        let frame = maximize.visualAbsoluteFrame()
        #expect(caption.maximizeButton == frame)
        #expect(caption.regions.contains { $0.contains(point: Point(x: frame.midX, y: frame.midY)) })
        #expect(caption.regions.allSatisfy { $0.minY < 32 && $0.maxY > 0 })
    }

    @Test("Overflowing controls are found unless an ancestor clips them", arguments: [false, true])
    func overflowingControl(isClipped: Bool) {
        let tester = ViewTester {
            VStack(spacing: 0) {
                Color.clear.frame(height: 100)
                overflow(clipped: isClipped)
            }.frame(width: 640, height: 400, alignment: .topLeading)
        }.setSize(Size(width: 640, height: 400)).performLayout()
        let window = UIWindow(configuration: .init())
        window.addSubview(tester.containerView)
        tester.performLayout()
        let caption = tester.containerView.windowCaptionInputRegions(height: 32, window: window)
        #expect(caption.regions.isEmpty == isClipped)
    }

    @ViewBuilder
    private func overflow(clipped: Bool) -> some View {
        if clipped {
            ScrollView {
                Button("Header") {}.frame(width: 100, height: 24).offset(y: -100)
            }.frame(width: 100, height: 24)
        } else {
            Button("Header") {}.frame(width: 100, height: 24).offset(y: -100)
        }
    }
}
