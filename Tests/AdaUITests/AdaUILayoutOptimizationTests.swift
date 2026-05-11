//
//  AdaUILayoutOptimizationTests.swift
//  AdaEngine
//

import Math
import Testing
@testable import AdaPlatform
@testable import AdaUI

@MainActor
struct AdaUILayoutOptimizationTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func repeatedContainerLayoutWithSameSizeSkipsCleanSubtreeLayout() {
        let counter = LayoutOptimizationCounter()
        let tester = ViewTester {
            CountingFixedView(counter: counter, size: Size(width: 120, height: 80))
        }
        .setSize(Size(width: 300, height: 200))
        .performLayout()

        counter.layoutPasses = 0
        UILayoutDebugCounters.isEnabled = true
        UILayoutDebugCounters.reset()
        tester.performLayout()
        let snapshot = UILayoutDebugCounters.snapshot
        UILayoutDebugCounters.isEnabled = false

        #expect(counter.layoutPasses == 0)
        #expect(snapshot.layoutPasses == 0)
    }

    @Test
    func geometryReaderDoesNotRebuildContentWhenGeometryIsUnchanged() {
        let counter = LayoutOptimizationCounter()
        let tester = ViewTester {
            GeometryReader { proxy in
                CountingFixedView(counter: counter, size: counter.recordGeometryBuild(size: proxy.size))
            }
        }
        .setSize(Size(width: 320, height: 180))
        .performLayout()

        let buildsAfterInitialLayout = counter.geometryBuilds
        tester.performLayout()

        #expect(counter.geometryBuilds == buildsAfterInitialLayout)
    }

    @Test
    func geometryReaderUsesParentProposalForOwnSize() {
        let counter = LayoutOptimizationCounter()
        let tester = ViewTester {
            GeometryReader { proxy in
                CountingFixedView(
                    counter: counter,
                    size: counter.recordGeometryBuild(size: proxy.size)
                )
                .frame(width: 960, height: 600)
            }
        }
        .setSize(Size(width: 320, height: 180))
        .performLayout()

        let rootContent = tester.containerView.viewTree.rootNode.contentNode

        #expect(rootContent.frame.size == Size(width: 320, height: 180))
        #expect(counter.geometryBuilds >= 1)
    }

    @Test
    func geometryReaderRebuildsContentWhenGeometryChanges() {
        let counter = LayoutOptimizationCounter()
        let tester = ViewTester {
            GeometryReader { proxy in
                CountingFixedView(counter: counter, size: counter.recordGeometryBuild(size: proxy.size))
            }
        }
        .setSize(Size(width: 320, height: 180))
        .performLayout()

        let buildsAfterInitialLayout = counter.geometryBuilds
        tester
            .setSize(Size(width: 360, height: 180))
            .performLayout()

        #expect(counter.geometryBuilds > buildsAfterInitialLayout)
    }

    @Test
    func geometryReaderReportsOwnFrameInCoordinateSpaces() {
        let recorder = GeometryFrameRecorder()
        let namedSpace = NamedViewCoordinateSpace.named("geometry-container")

        _ = ViewTester {
            ZStack(anchor: .topLeading) {
                GeometryReader { proxy in
                    GeometryFrameProbe(
                        recorder: recorder,
                        localFrame: proxy.frame(in: .local),
                        globalFrame: proxy.frame(in: .global),
                        namedFrame: proxy.frame(in: namedSpace),
                        size: proxy.size
                    )
                }
                .frame(width: 80, height: 40)
                .offset(x: 25, y: 15)
            }
            .frame(width: 200, height: 100, alignment: .topLeading)
            .coordinateSpace(namedSpace)
        }
        .setSize(Size(width: 300, height: 200))
        .performLayout()

        #expect(recorder.size == Size(width: 80, height: 40))
        #expect(recorder.localFrame == Rect(x: 0, y: 0, width: 80, height: 40))
        #expect(recorder.namedFrame == Rect(x: 25, y: 15, width: 80, height: 40))
        #expect(recorder.globalFrame == Rect(x: 75, y: 65, width: 80, height: 40))
    }

    @Test
    func stateChangeStillUpdatesLayoutOnNextLayoutPass() {
        let counter = LayoutOptimizationCounter()
        let tester = ViewTester {
            StatefulLayoutOptimizationView(counter: counter)
        }
        .setSize(Size(width: 300, height: 200))
        .performLayout()

        let initialFrame = tester.findNodeByAccessibilityIdentifier("state-child")?.frame
        let toggleFrame = tester.findNodeByAccessibilityIdentifier("toggle")?.absoluteFrame() ?? .zero
        let toggleCenter = Point(toggleFrame.midX, toggleFrame.midY)
        tester.sendMouseEvent(at: toggleCenter, button: .left, phase: .began)
        tester.sendMouseEvent(at: toggleCenter, button: .left, phase: .ended)
        tester.performLayout()

        let updatedFrame = tester.findNodeByAccessibilityIdentifier("state-child")?.frame
        #expect(initialFrame?.height == 30)
        #expect(updatedFrame?.height == 80)
    }

    @Test
    func stackLayoutReusesMeasurementsInsidePlacementPass() {
        let counter = LayoutOptimizationCounter()
        let tester = ViewTester {
            VStack(spacing: 4) {
                CountingFixedView(counter: counter, size: Size(width: 40, height: 10))
                CountingFixedView(counter: counter, size: Size(width: 50, height: 20))
                CountingFixedView(counter: counter, size: Size(width: 60, height: 30))
            }
        }
        .setSize(Size(width: 300, height: 200))
        .performLayout()

        counter.sizeThatFitsCalls = 0
        tester
            .setSize(Size(width: 320, height: 200))
            .performLayout()

        #expect(counter.sizeThatFitsCalls <= 9)
    }
}

@MainActor
private final class LayoutOptimizationCounter {
    var geometryBuilds = 0
    var layoutPasses = 0
    var sizeThatFitsCalls = 0

    func recordGeometryBuild(size: Size) -> Size {
        geometryBuilds += 1
        return size
    }
}

@MainActor
private final class GeometryFrameRecorder {
    var localFrame = Rect.zero
    var globalFrame = Rect.zero
    var namedFrame = Rect.zero
    var size = Size.zero
}

private struct GeometryFrameProbe: View, ViewNodeBuilder {
    let recorder: GeometryFrameRecorder
    let localFrame: Rect
    let globalFrame: Rect
    let namedFrame: Rect
    let size: Size

    var body: Never {
        fatalError()
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        recorder.localFrame = localFrame
        recorder.globalFrame = globalFrame
        recorder.namedFrame = namedFrame
        recorder.size = size
        return GeometryFrameProbeNode(content: self)
    }
}

private final class GeometryFrameProbeNode: ViewNode {
    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        proposal.replacingUnspecifiedDimensions()
    }
}

private struct CountingFixedView: View, ViewNodeBuilder {
    let counter: LayoutOptimizationCounter
    let size: Size

    var body: Never {
        fatalError()
    }

    func buildViewNode(in context: BuildContext) -> ViewNode {
        CountingFixedViewNode(content: self, counter: counter, size: size)
    }
}

private final class CountingFixedViewNode: ViewNode {
    private let counter: LayoutOptimizationCounter
    private var fixedSize: Size

    init(content: CountingFixedView, counter: LayoutOptimizationCounter, size: Size) {
        self.counter = counter
        self.fixedSize = size
        super.init(content: content)
    }

    override func update(from newNode: ViewNode) {
        if let other = newNode as? CountingFixedViewNode {
            self.fixedSize = other.fixedSize
        }
        super.update(from: newNode)
    }

    override func sizeThatFits(_ proposal: ProposedViewSize) -> Size {
        counter.sizeThatFitsCalls += 1
        return fixedSize
    }

    override func performLayout() {
        counter.layoutPasses += 1
        super.performLayout()
    }
}

private struct StatefulLayoutOptimizationView: View {
    let counter: LayoutOptimizationCounter
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button("toggle") {
                expanded.toggle()
            }
            .frame(width: 100, height: 40)
            .accessibilityIdentifier("toggle")

            CountingFixedView(
                counter: counter,
                size: Size(width: 80, height: expanded ? 80 : 30)
            )
            .accessibilityIdentifier("state-child")
        }
    }
}
