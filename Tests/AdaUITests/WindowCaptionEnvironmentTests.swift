@testable import AdaPlatform
@_spi(Internal) @testable import AdaUI
import Math
import Testing

@MainActor
struct WindowCaptionEnvironmentTests {
    init() async throws { try Application.prepareForTest() }

    #if os(Windows)
    @Test("Repeated caption layout keeps geometry content stable and still reflects maximize changes")
    func captionLayoutDoesNotRebuildContent() {
        let window = UIWindow(configuration: .init(
            frame: Rect(x: 0, y: 0, width: 640, height: 400),
            titleBar: .init(background: .transparent, reservesSafeArea: false, dragRegionHeight: 32)
        ))
        let native = EnvironmentRecordingWindow()
        window.systemWindow = native
        let builds = CaptionGeometryBuilds()
        let tester = ViewTester {
            GeometryReader { _ in
                builds.record()
                return Text("Scene content")
            }
        }.setSize(Size(width: 640, height: 400))
        window.addSubview(tester.containerView)
        tester.performLayout()
        let initial = builds.count
        let caption = tester.containerView.rootEnvironmentValues().windowCaption
        for _ in 0..<5 {
            tester.containerView.setNeedsLayout()
            tester.performLayout()
        }
        #expect(initial > 0)
        #expect(builds.count == initial)
        #expect(tester.containerView.rootEnvironmentValues().windowCaption == caption)

        native.isMaximized = true
        tester.containerView.setNeedsLayout()
        tester.performLayout()
        #expect(builds.count > initial)
        #expect(tester.containerView.rootEnvironmentValues().windowCaption.isMaximized)
    }

    @Test("Caption command identity changes with its host and routes to that host")
    func captionCommandsRemainWindowBound() {
        let first = UIWindow(configuration: .init())
        let second = UIWindow(configuration: .init())
        let firstNative = EnvironmentRecordingWindow()
        let secondNative = EnvironmentRecordingWindow()
        first.systemWindow = firstNative
        second.systemWindow = secondNative
        let firstCaption = WindowCaptionPresentation(isVisible: true, target: first.captionCommandTarget)
        let secondCaption = WindowCaptionPresentation(isVisible: true, target: second.captionCommandTarget)
        #expect(firstCaption != secondCaption)
        firstCaption.action(.minimize)
        secondCaption.action(.close)
        #expect(firstNative.actions == [.minimize])
        #expect(secondNative.actions == [.close])
    }
    #endif
}

@MainActor
private final class CaptionGeometryBuilds {
    var count = 0
    func record() { count += 1 }
}

@MainActor
private final class EnvironmentRecordingWindow: SystemWindow {
    var title = "Environment test"
    var size = Size(width: 640, height: 400)
    var position = Point.zero
    var isMaximized = false
    var actions: [WindowCaptionAction] = []

    func performCaptionAction(_ action: WindowCaptionAction) { actions.append(action) }
}
