import AdaInput
import AdaPlatform
@testable import AdaUI
import AdaUtils
import Foundation
import Math
import Testing

@MainActor
struct AdaptiveLayoutTests {
    init() async throws { try Application.prepareForTest() }

    @Test
    func hingeOpeningIsNormalizedAndMissingHingesRemainAbsent() {
        #expect(DeviceHinge(status: .closed, angle: 0).openingPercentage == 0)
        #expect(DeviceHinge(status: .fullyOpen, angle: .pi).openingPercentage == 100)
        #expect(DeviceHinge(status: .partiallyOpen, angle: .pi / 2).openingPercentage == 50)
        #expect(DeviceHinge(status: .partiallyOpen, angle: 10).openingProgress == 1)
        #expect(DeviceHinge(status: .unknown, angle: .nan).openingProgress == 0)
        #expect(EnvironmentValues().deviceHinge == nil)
    }

    @Test
    func hingeEventsReportOpeningPercentageAndIgnoreRepeatedValues() {
        let window = UIWindow(frame: Rect(x: 0, y: 0, width: 600, height: 500))
        let windowID = window.id
        let recorder = AdaptiveHingeRecorder()
        let subscription = EventManager.default.subscribe(to: WindowHingeChanged.self) { event in
            // UIWindow publishes this event synchronously from its MainActor property.
            MainActor.assumeIsolated {
                if event.windowID == windowID { recorder.events.append(event) }
            }
        }
        defer { subscription.cancel() }
        window.deviceHinge = DeviceHinge(status: .closed, angle: 0)
        window.deviceHinge = DeviceHinge(status: .partiallyOpen, angle: .pi / 2)
        window.deviceHinge = DeviceHinge(status: .partiallyOpen, angle: .pi / 2)
        window.deviceHinge = DeviceHinge(status: .fullyOpen, angle: .pi)
        window.deviceHinge = nil
        #expect(recorder.events.map(\.openingPercentage) == [0, 50, 100, nil])
        #expect(recorder.events[1].previousHinge?.openingPercentage == 0)
        #expect(recorder.events[3].previousHinge?.openingPercentage == 100)
    }

    @Test
    func windowInspectionReportsAdaptiveGeometry() throws {
        let tester = ViewTester { Color.clear }.setSize(Size(width: 600, height: 500))
        tester.containerView.horizontalSizeClass = .regular
        tester.containerView.verticalSizeClass = .compact
        tester.containerView.safeAreaInsets = EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84)
        tester.containerView.deviceHinge = DeviceHinge(status: .partiallyOpen, angle: .pi / 2)
        let summary = tester.containerView.uiWindowSummary()
        let decoded = try JSONDecoder().decode(UIWindowSummary.self, from: JSONEncoder().encode(summary))
        #expect(decoded.layoutTraits?.horizontalSizeClass == .regular)
        #expect(decoded.layoutTraits?.safeAreaInsets.trailing == 84)
        #expect(decoded.layoutTraits?.hinge?.openingPercentage == 50)
    }

    @Test
    func compactWindowsRetainOnePaneAndExpandedWindowsRespectTheFold() {
        let compact = AdaptiveSplitFrames(size: Size(width: 900, height: 700), horizontalSizeClass: .compact, division: nil)
        #expect(!compact.isExpanded)
        #expect(compact.primary == .zero)
        #expect(compact.secondary.width == 900)
        let fold = ViewReservedRegion(id: "fold", kind: .division, frame: Rect(x: 440, y: 0, width: 20, height: 700),
            margins: EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 12))
        let expanded = AdaptiveSplitFrames(size: Size(width: 900, height: 700), horizontalSizeClass: .regular, division: fold)
        #expect(expanded.isExpanded)
        #expect(expanded.primary.maxX == 432)
        #expect(expanded.secondary.minX == 472)
        #expect(expanded.secondary.maxX == 900)
        let horizontal = ViewReservedRegion(id: "fold", kind: .division, frame: Rect(x: 0, y: 280, width: 900, height: 20))
        let tabletop = AdaptiveSplitFrames(size: Size(width: 900, height: 700), horizontalSizeClass: .regular, division: horizontal)
        #expect(tabletop.primary.maxY == 280)
        #expect(tabletop.secondary.minY == 300)
        let inactive = ViewReservedRegion(id: "fold", kind: .division, frame: .zero, isActive: false)
        let flat = AdaptiveSplitFrames(size: Size(width: 900, height: 700), horizontalSizeClass: .regular, division: inactive)
        #expect(flat.primary.width == 442)
        #expect(flat.secondary.minX == 458)
    }

    @Test
    func partiallyOpenPortraitUsesTwoRowsWithoutNativeDivisionRegions() {
        let hinge = DeviceHinge(status: .partiallyOpen, angle: .pi * 0.7)
        let frames = AdaptiveSplitFrames(size: Size(width: 669, height: 835), horizontalSizeClass: .regular, division: nil, hinge: hinge)
        #expect(frames.isExpanded)
        #expect(frames.primary.width == 669)
        #expect(frames.secondary.width == 669)
        #expect(frames.primary.maxY == 409.5)
        #expect(frames.secondary.minY == 425.5)
        #expect(frames.secondary.maxY == 835)
        let narrow = AdaptiveSplitFrames(size: Size(width: 390, height: 835), horizontalSizeClass: .compact, division: nil, hinge: hinge)
        #expect(narrow.isExpanded)
        #expect(narrow.primary.maxY < narrow.secondary.minY)
        let open = AdaptiveSplitFrames(size: Size(width: 669, height: 835), horizontalSizeClass: .regular, division: nil,
            hinge: DeviceHinge(status: .fullyOpen, angle: .pi))
        #expect(open.primary.maxX < open.secondary.minX)
        let landscape = AdaptiveSplitFrames(size: Size(width: 835, height: 669), horizontalSizeClass: .regular, division: nil, hinge: hinge)
        #expect(landscape.primary.maxX < landscape.secondary.minX)
    }

    @Test
    func horizontalHingeUsesAvailableHeightAndPreservesPhysicalMargins() {
        let fold = ViewReservedRegion(id: "fold", kind: .division, frame: Rect(x: 0, y: 393.5, width: 550, height: 0),
            margins: EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        let frames = AdaptiveSplitFrames(size: Size(width: 550, height: 835), horizontalSizeClass: .regular, division: fold)
        #expect(frames.isExpanded)
        #expect(frames.primary.maxY == 385.5)
        #expect(frames.secondary.minY == 401.5)
        #expect(frames.secondary.maxY == 835)
    }

    @Test
    func nativeTraitsPropagateToTheExistingViewTree() throws {
        let tester = ViewTester {
            AdaptiveTraitProbe()
        }.setSize(Size(width: 600, height: 500)).performLayout()
        #expect(try #require(tester.findNodeByAccessibilityIdentifier("trait-probe")).frame.width == 20)
        tester.containerView.horizontalSizeClass = .regular
        tester.containerView.deviceHinge = DeviceHinge(status: .partiallyOpen, angle: .pi / 2)
        tester.performLayout()
        let expanded = try #require(tester.findNodeByAccessibilityIdentifier("trait-probe"))
        #expect(expanded.frame.width == 100)
        #expect(expanded.frame.height == 50)
        tester.containerView.horizontalSizeClass = .compact
        tester.containerView.deviceHinge = nil
        tester.performLayout()
        #expect(try #require(tester.findNodeByAccessibilityIdentifier("trait-probe")).frame.width == 20)
    }

    @Test
    func expandedSafeAreaReceivesInputAtPhysicalDisplayEdges() {
        let actions = AdaptiveActionCounter()
        let tester = ViewTester {
            Button { actions.count += 1 } label: { Color.clear }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea([.horizontal, .bottom])
        }.setSize(Size(width: 951, height: 669))
        tester.containerView.safeAreaInsets = EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84)
        tester.performLayout()
        let point = Point(925, 655)
        let event = MouseEvent(window: .empty, button: .left, mousePosition: point, phase: .began, modifierKeys: [], time: 0)
        #expect(tester.containerView.point(inside: point, with: event))
        #expect(tester.containerView.hitTest(point, with: event) != nil)
        tester.sendMouseEvent(at: point, phase: .began)
        tester.sendMouseEvent(at: point, phase: .ended)
        #expect(actions.count == 1)
    }

    @Test
    func splitComposerAcceptsTouchesAndTextAcrossDisplayChanges() throws {
        var draft = ""
        let tester = ViewTester {
            AdaptiveComposerProbe(text: Binding(get: { draft }, set: { draft = $0 }))
        }.setSize(Size(width: 900, height: 700))
        tester.containerView.horizontalSizeClass = .regular
        tester.performLayout()

        func enter(_ text: String) throws {
            let frame = try #require(tester.findNodeByAccessibilityIdentifier("split-prompt")).visualAbsoluteFrame()
            let point = Point(frame.midX, frame.midY)
            let contact = RID()
            tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .began, time: 0, contactID: contact)])
            tester.containerView.onTouchesEvent([TouchEvent(window: .empty, location: point, phase: .ended, time: 0.1, contactID: contact)])
            #expect(tester.containerView.hasFocusedInputNode)
            tester.sendTextInput(text)
        }

        try enter("Hello")
        #expect(draft == "Hello")
        tester.containerView.horizontalSizeClass = .compact
        tester.setSize(Size(width: 466, height: 678)).performLayout()
        try enter(" Duo")
        #expect(draft == "Hello Duo")
        tester.containerView.horizontalSizeClass = .regular
        tester.setSize(Size(width: 900, height: 700)).performLayout()
        try enter("!")
        #expect(draft == "Hello Duo!")
    }

    @Test
    func deferredWorkspacePolicyReservesNavigationClearanceOnFirstLayout() throws {
        let tester = ViewTester {
            NavigationStack {
                GeometryReader { _ in
                    AdaptiveWorkspaceOriginProbe(showsFiles: false)
                        .navigationBarContentExtendsUnderNavigationBar()
                }
                .navigationTitle("Project")
            }
        }.setSize(Size(width: 669, height: 835)).performLayout()
        #expect(try #require(tester.findNodeByAccessibilityIdentifier("workspace-accessory")).absoluteFrame().minY == 92)
    }

    @Test
    func compositeWorkspaceKeepsItsOriginWhenScrollContentChanges() throws {
        var showsFiles = false
        let tester = ViewTester {
            NavigationStack {
                AdaptiveWorkspaceOriginProbe(showsFiles: showsFiles)
                    .navigationBarContentExtendsUnderNavigationBar()
                    .navigationTitle("Project")
            }
        }.setSize(Size(width: 600, height: 700)).performLayout()
        let before = try #require(tester.findNodeByAccessibilityIdentifier("workspace-accessory")).absoluteFrame()
        #expect(before.minY == 92)
        showsFiles = true
        tester.invalidateContent().performLayout()
        let files = try #require(tester.findNodeByAccessibilityIdentifier("workspace-accessory")).absoluteFrame()
        #expect(files == before)
        showsFiles = false
        tester.invalidateContent().performLayout()
        #expect(try #require(tester.findNodeByAccessibilityIdentifier("workspace-accessory")).absoluteFrame() == before)
    }

    @Test
    func sideControlsAvoidTopAndBottomOcclusionsAfterRotation() throws {
        let actions = AdaptiveActionCounter()
        let tester = ViewTester {
            NavigationStack {
                Color.clear.navigationTitle("Project")
                    .navigationBarTrailingItems { AdaptiveNavigationControls(actions: actions) }
            }
            .environment(\.displaySafeAreaInsets, EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 80))
        }.setSize(Size(width: 600, height: 700))
        tester.containerView.userInterfaceIdiom = .phone
        tester.containerView.reservedRegions = [
            ViewReservedRegion(id: "camera", kind: .occlusion, frame: Rect(x: 520, y: 0, width: 80, height: 160),
                margins: EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0)),
            ViewReservedRegion(id: "bottom", kind: .occlusion, frame: Rect(x: 520, y: 520, width: 80, height: 180))
        ]
        tester.performLayout()
        let first = try #require(tester.findNodeByAccessibilityIdentifier("adaptive-first")).absoluteFrame()
        let second = try #require(tester.findNodeByAccessibilityIdentifier("adaptive-second")).absoluteFrame()
        #expect(first.minY >= 172)
        #expect(second.maxY < 520)
        tester.containerView.reservedRegions.removeFirst()
        tester.performLayout()
        let rotated = try #require(tester.findNodeByAccessibilityIdentifier("adaptive-first")).absoluteFrame()
        #expect(rotated.minY == 16)
        tester.sendMouseEvent(at: Point(rotated.midX, rotated.midY), phase: .began)
        tester.sendMouseEvent(at: Point(rotated.midX, rotated.midY), phase: .ended)
        #expect(actions.count == 1)
    }

    @Test
    func sideNavigationControlsReflowAndStayInteractive() throws {
        let actions = AdaptiveActionCounter()
        let tester = ViewTester {
            NavigationStack {
                Color.clear.navigationTitle("Project")
                    .navigationBarTrailingItems { AdaptiveNavigationControls(actions: actions) }
            }
        }.setSize(Size(width: 600, height: 700))
        tester.containerView.userInterfaceIdiom = .phone
        tester.containerView.safeAreaInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 80)
        tester.containerView.navigationBarControlsTopInset = 112
        tester.performLayout()
        let first = try #require(tester.findNodeByAccessibilityIdentifier("adaptive-first")).visualAbsoluteFrame()
        let second = try #require(tester.findNodeByAccessibilityIdentifier("adaptive-second")).visualAbsoluteFrame()
        #expect(abs(first.midX - second.midX) < 0.5)
        #expect(second.minY >= first.maxY)
        #expect(first.minY == 112)
        tester.sendMouseEvent(at: Point(first.midX, first.midY), phase: .began)
        tester.sendMouseEvent(at: Point(first.midX, first.midY), phase: .ended)
        #expect(actions.count == 1)
        tester.containerView.safeAreaInsets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        tester.performLayout()
        let flatFirst = try #require(tester.findNodeByAccessibilityIdentifier("adaptive-first")).visualAbsoluteFrame()
        let flatSecond = try #require(tester.findNodeByAccessibilityIdentifier("adaptive-second")).visualAbsoluteFrame()
        #expect(abs(flatFirst.midY - flatSecond.midY) < 0.5)
        #expect(flatSecond.minX >= flatFirst.maxX)
    }
}

private struct AdaptiveWorkspaceOriginProbe: View {
    @Environment(\.navigationBarContentInset) private var topInset
    let showsFiles: Bool

    var body: some View {
        GeometryReader { _ in
            ZStack(anchor: .topLeading) {
                if showsFiles {
                    ScrollView(.vertical, respectsSafeArea: false, extendsUnderNavigationBar: true) {
                        Color.clear.frame(height: 1000)
                    }
                } else {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Color.red.frame(width: 40, height: 40)
                    .accessibilityIdentifier("workspace-accessory")
                    .padding(.top, topInset)
            }
        }
    }
}

private struct AdaptiveTraitProbe: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.deviceHinge) private var hinge
    var body: some View {
        Color.clear.frame(width: horizontalSizeClass == .regular ? 100 : 20, height: hinge?.openingPercentage ?? 2)
            .accessibilityIdentifier("trait-probe")
    }
}

private struct AdaptiveComposerProbe: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var text: String

    var body: some View {
        GeometryReader { geometry in
            let layout = AdaptiveSplitFrames(size: geometry.size, horizontalSizeClass: horizontalSizeClass, division: nil)
            ZStack(anchor: .topLeading) {
                if layout.isExpanded {
                    Color.clear.frame(width: layout.primary.width, height: layout.primary.height)
                }
                TabView(selection: .constant(0)) {
                    Tab("Build", value: 0) {
                        TextEditor(text: _text, showsLineNumbers: false, wrapsLines: true)
                            .accessibilityIdentifier("split-prompt")
                            .frame(height: 64)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                    .id("workspace-content")
                    .tabViewStyle(AdaptiveComposerTabStyle(expanded: layout.isExpanded))
                    .padding(.top, layout.isExpanded ? 92 : 0)
                    .frame(width: layout.secondary.width, height: layout.secondary.height, alignment: .bottom)
                    .offset(x: layout.secondary.minX, y: layout.secondary.minY)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .mask(RectangleShape())
    }
}

private struct AdaptiveComposerTabStyle: TabViewStyle {
    let expanded: Bool

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if expanded { configuration.content } else { LiquidGlassTabBarStyle().makeBody(configuration: configuration) }
    }
}

@MainActor
private final class AdaptiveActionCounter { var count = 0 }

@MainActor
private final class AdaptiveHingeRecorder { var events: [WindowHingeChanged] = [] }

private struct AdaptiveNavigationControls: View {
    @Environment(\.navigationBarControlsAxis) private var axis
    let actions: AdaptiveActionCounter
    var body: some View {
        let layout = axis == .vertical ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Button("First") { actions.count += 1 }.frame(width: 44, height: 44).accessibilityIdentifier("adaptive-first")
            Button("Second") {}.frame(width: 44, height: 44).accessibilityIdentifier("adaptive-second")
        }
    }
}
