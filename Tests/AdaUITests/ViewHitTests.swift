//
//  ViewHitTests.swift
//  AdaEngineTests
//
//  Created by vladislav.prusakov on 09.08.2024.
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
import AdaInput
import Math

@MainActor
struct ViewHitTests {
    init() async throws {
        try Application.prepareForTest()
    }

    /// Verifies horizontal `ScrollView` hit-testing uses the current `contentOffset`.
    ///
    /// Given:
    /// - 3 fixed-width buttons (`first`, `second`, `third`) inside horizontal scroll content;
    /// - viewport width that can show about one button at a time.
    ///
    /// When:
    /// - wheel scroll shifts content horizontally;
    /// - user taps center of the viewport.
    ///
    /// Then:
    /// - hit-test must target the button that is currently visible at that point (`third`);
    /// - tap callback must be invoked for the same identifier.
    ///
    /// Regression protected:
    /// - hit-test ignores scroll offset and still resolves pre-scroll nodes.
    @Test
    func scrollViewHitTest_usesContentOffset() {
        final class TapRecorder {
            var taps: [String] = []
        }

        struct ScrollableButtonsView: View {
            let onTap: (String) -> Void

            var body: some View {
                ScrollView(.horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        tapTarget("first")
                        tapTarget("second")
                        tapTarget("third")
                    }
                    .padding(8)
                }
                .frame(width: 140, height: 64)
                .accessibilityIdentifier("scroll")
            }

            private func tapTarget(_ id: String) -> some View {
                Button(action: {
                    onTap(id)
                }) {
                    HStack(alignment: .center, spacing: 0) {}
                        .frame(width: 90, height: 24)
                }
                .accessibilityIdentifier(id)
            }
        }

        // Arrange
        let recorder = TapRecorder()
        let tester = ViewTester {
            ScrollableButtonsView(onTap: {
                recorder.taps.append($0)
            })
        }
        .setSize(Size(width: 140, height: 80))
        .performLayout()

        let scrollPoint = Point(70, 32)
        // First wheel event begins scroll phase, second applies delta.
        // Act: perform horizontal scroll.
        tester.sendMouseEvent(
            at: scrollPoint,
            button: MouseButton.scrollWheel,
            phase: MouseEvent.Phase.changed,
            scrollDelta: Point(-1.5, 0),
            time: 0
        )
        tester.sendMouseEvent(
            at: scrollPoint,
            button: MouseButton.scrollWheel,
            phase: MouseEvent.Phase.changed,
            scrollDelta: Point(-1.5, 0),
            time: 0.01
        )

        let targetOnMouseDown = tester.sendMouseEvent(
            at: scrollPoint,
            phase: MouseEvent.Phase.began,
            time: 0.02
        )
        tester.sendMouseEvent(
            at: scrollPoint,
            phase: MouseEvent.Phase.ended,
            time: 0.03
        )

        // Assert
        #expect(targetOnMouseDown?.accessibilityIdentifier == "third")
        #expect(recorder.taps.last == "third")
    }

    /// Verifies vertical `ScrollView` consumes wheel ticks and updates hittable content.
    ///
    /// Given:
    /// - long vertical list (`item-0 ... item-13`) in a small viewport;
    /// - `item-12` starts outside visible region.
    ///
    /// When:
    /// - several wheel events are sent to the scroll view.
    ///
    /// Then:
    /// - `item-12` becomes hittable in viewport coordinates;
    /// - tapping found point triggers exactly `item-12` action.
    ///
    /// Regression protected:
    /// - vertical offset not updated even though wheel events are delivered;
    /// - hit-test uses stale coordinates before scroll.
    @Test
    func verticalScrollView_acceptsDiscreteWheelTicks() {
        final class TapRecorder {
            var taps: [String] = []
        }

        struct VerticalListView: View {
            let onTap: (String) -> Void

            var body: some View {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<14, id: \.self) { index in
                            Button(action: {
                                onTap("item-\(index)")
                            }) {
                                HStack(alignment: .center, spacing: 0) {}
                                    .frame(width: 120, height: 24)
                            }
                            .accessibilityIdentifier("item-\(index)")
                        }
                    }
                    .padding(8)
                }
                .frame(width: 140, height: 80)
            }
        }

        // Arrange
        let recorder = TapRecorder()
        let tester = ViewTester {
            VerticalListView(onTap: { recorder.taps.append($0) })
        }
        .setSize(Size(width: 160, height: 120))
        .performLayout()

        let targetIdentifier = "item-12"
        let viewportRect = Rect(origin: .zero, size: Size(width: 160, height: 120))
        #expect(tester.findHitPoint(forAccessibilityIdentifier: targetIdentifier, in: viewportRect, step: 2) == nil)

        // Act: perform vertical scroll.
        let scrollPoint = Point(40, 40)
        for tick in 0..<4 {
            tester.sendMouseEvent(
                at: scrollPoint,
                button: MouseButton.scrollWheel,
                phase: MouseEvent.Phase.changed,
                scrollDelta: Point(0, -1.5),
                time: Float(tick) * 0.01
            )
        }

        guard let clickPoint = tester.findHitPoint(
            forAccessibilityIdentifier: targetIdentifier,
            in: viewportRect,
            step: 2
        ) else {
            let ids = tester.collectHitAccessibilityIdentifiers(in: viewportRect, step: 4).sorted().joined(separator: ", ")
            Issue.record("\(targetIdentifier) is not hittable after vertical wheel ticks. Hittable ids: \(ids)")
            return
        }

        // Assert: target item is now reachable and action is invoked for that exact item.
        let targetOnMouseDown = tester.sendMouseEvent(
            at: clickPoint,
            phase: MouseEvent.Phase.began,
            time: 1
        )
        tester.sendMouseEvent(
            at: clickPoint,
            phase: MouseEvent.Phase.ended,
            time: 1.01
        )

        #expect(targetOnMouseDown?.accessibilityIdentifier == targetIdentifier)
        #expect(recorder.taps.last == targetIdentifier)
    }

    /// Verifies vertical scrolling remains active for bi-directional scroll views.
    ///
    /// Given:
    /// - `ScrollView([.vertical, .horizontal])` with content taller than viewport.
    ///
    /// When:
    /// - vertical wheel ticks are sent.
    ///
    /// Then:
    /// - deep element (`item-12`) becomes reachable and tappable.
    ///
    /// Regression protected:
    /// - enabling horizontal axis accidentally disables vertical offset updates.
    @Test
    func biDirectionalScrollView_acceptsVerticalWheelTicks() {
        final class TapRecorder {
            var taps: [String] = []
        }

        struct BiDirectionalListView: View {
            let onTap: (String) -> Void

            var body: some View {
                ScrollView([.vertical, .horizontal]) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<14, id: \.self) { index in
                                Button(action: {
                                    onTap("item-\(index)")
                                }) {
                                    HStack(alignment: .center, spacing: 0) {}
                                        .frame(width: 120, height: 24)
                                }
                                .accessibilityIdentifier("item-\(index)")
                            }
                        }
                        .frame(width: 160)
                    }
                    .padding(8)
                }
                .frame(width: 180, height: 90)
            }
        }

        // Arrange
        let recorder = TapRecorder()
        let tester = ViewTester {
            BiDirectionalListView(onTap: { recorder.taps.append($0) })
        }
        .setSize(Size(width: 220, height: 140))
        .performLayout()

        let targetIdentifier = "item-12"
        let viewportRect = Rect(origin: .zero, size: Size(width: 220, height: 140))
        #expect(tester.findHitPoint(forAccessibilityIdentifier: targetIdentifier, in: viewportRect, step: 2) == nil)

        // Act: vertical wheel ticks inside bi-directional scroll view.
        let scrollPoint = Point(60, 50)
        for tick in 0..<8 {
            tester.sendMouseEvent(
                at: scrollPoint,
                button: MouseButton.scrollWheel,
                phase: MouseEvent.Phase.changed,
                scrollDelta: Point(0, -1.5),
                time: Float(tick) * 0.01
            )
        }

        guard let clickPoint = tester.findHitPoint(
            forAccessibilityIdentifier: targetIdentifier,
            in: viewportRect,
            step: 2
        ) else {
            let ids = tester.collectHitAccessibilityIdentifiers(in: viewportRect, step: 4).sorted().joined(separator: ", ")
            Issue.record("\(targetIdentifier) is not hittable after vertical ticks in bi-directional scroll view. Hittable ids: \(ids)")
            return
        }

        // Assert
        let targetOnMouseDown = tester.sendMouseEvent(
            at: clickPoint,
            phase: MouseEvent.Phase.began,
            time: 1
        )
        tester.sendMouseEvent(
            at: clickPoint,
            phase: MouseEvent.Phase.ended,
            time: 1.01
        )

        #expect(targetOnMouseDown?.accessibilityIdentifier == targetIdentifier)
        #expect(recorder.taps.last == targetIdentifier)
    }

    /// Verifies bi-directional `ScrollView` inside `VStack` fills remaining height and scrolls.
    ///
    /// Given:
    /// - header at top;
    /// - scroll view below with no explicit fixed height (Kanban-like composition);
    /// - content taller than available area.
    ///
    /// When:
    /// - vertical wheel ticks are sent.
    ///
    /// Then:
    /// - lower item (`vstack-item-14`) becomes hittable in viewport;
    /// - tap callback receives the same id.
    ///
    /// Regression protected:
    /// - scroll view reports content as ideal size on scroll axis;
    /// - parent stack allocates only content height, removing overflow and disabling scroll.
    @Test
    func biDirectionalScrollView_inVStack_expandsRemainingSpaceAndScrollsVertically() {
        final class TapRecorder {
            var taps: [String] = []
        }

        struct VStackHostedScrollView: View {
            let onTap: (String) -> Void

            var body: some View {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 0) {}
                        .frame(height: 36)

                    ScrollView([.vertical, .horizontal]) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(0..<16, id: \.self) { index in
                                    Button(action: {
                                        onTap("vstack-item-\(index)")
                                    }) {
                                        HStack(alignment: .center, spacing: 0) {}
                                            .frame(width: 120, height: 24)
                                    }
                                    .accessibilityIdentifier("vstack-item-\(index)")
                                }
                            }
                            .frame(width: 160)
                        }
                        .padding(8)
                    }
                }
                .padding(8)
            }
        }

        // Arrange
        let recorder = TapRecorder()
        let tester = ViewTester {
            VStackHostedScrollView(onTap: { recorder.taps.append($0) })
        }
        .setSize(Size(width: 220, height: 160))
        .performLayout()

        let targetIdentifier = "vstack-item-14"
        let viewportRect = Rect(origin: .zero, size: Size(width: 220, height: 160))
        #expect(tester.findHitPoint(forAccessibilityIdentifier: targetIdentifier, in: viewportRect, step: 2) == nil)

        // Act
        let scrollPoint = Point(70, 90)
        for tick in 0..<10 {
            tester.sendMouseEvent(
                at: scrollPoint,
                button: MouseButton.scrollWheel,
                phase: MouseEvent.Phase.changed,
                scrollDelta: Point(0, -1.5),
                time: Float(tick) * 0.02
            )
        }

        guard let clickPoint = tester.findHitPoint(
            forAccessibilityIdentifier: targetIdentifier,
            in: viewportRect,
            step: 2
        ) else {
            let ids = tester.collectHitAccessibilityIdentifiers(in: viewportRect, step: 4).sorted().joined(separator: ", ")
            Issue.record("\(targetIdentifier) is not hittable after vertical ticks in VStack-hosted scroll view. Hittable ids: \(ids)")
            return
        }

        // Assert
        let targetOnMouseDown = tester.sendMouseEvent(
            at: clickPoint,
            phase: MouseEvent.Phase.began,
            time: 1
        )
        tester.sendMouseEvent(
            at: clickPoint,
            phase: MouseEvent.Phase.ended,
            time: 1.01
        )

        #expect(targetOnMouseDown?.accessibilityIdentifier == targetIdentifier)
        #expect(recorder.taps.last == targetIdentifier)
    }

    /// Verifies horizontal scrolling + hit-testing in Kanban-like fixed-width columns.
    ///
    /// Given:
    /// - 4 columns inside horizontal scroll area;
    /// - `review<` control starts outside viewport.
    ///
    /// When:
    /// - wheel scroll moves content to reveal right columns;
    /// - test searches visible area for `review<` and performs click.
    ///
    /// Then:
    /// - hit node must be exactly `review<`;
    /// - callback must report `review<`, not a stale offscreen control.
    ///
    /// Regression protected:
    /// - stale active node after scroll;
    /// - mismatch between visual position and hit-tested target.
    @Test
    func kanbanLikeScrollHitTest_targetsButtonInVisibleColumn() {
        final class TapRecorder {
            var taps: [String] = []
        }

        struct ColumnView: View {
            let id: String
            let hasLeft: Bool
            let hasRight: Bool
            let onTap: (String) -> Void

            var body: some View {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 4) {
                        HStack(alignment: .center, spacing: 0) {}
                            .frame(width: 64, height: 20)
                        Spacer()
                        HStack(alignment: .center, spacing: 0) {}
                            .frame(width: 12, height: 20)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 0) {}
                            .frame(height: 48)
                    }

                    HStack(alignment: .center, spacing: 6) {
                        if hasLeft {
                            Button(action: { onTap("\(id)<") }) {
                                HStack(alignment: .center, spacing: 0) {}
                                    .frame(width: 22, height: 24)
                            }
                            .accessibilityIdentifier("\(id)<")
                        }

                        Spacer()

                        if hasRight {
                            Button(action: { onTap("\(id)>") }) {
                                HStack(alignment: .center, spacing: 0) {}
                                    .frame(width: 22, height: 24)
                            }
                            .accessibilityIdentifier("\(id)>")
                        }
                    }

                    Spacer(minLength: 4)
                }
                .padding(12)
                .frame(height: 220)
            }
        }

        struct KanbanLikeView: View {
            let onTap: (String) -> Void

            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 0) {}
                        .frame(height: 80)

                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            ColumnView(id: "backlog", hasLeft: false, hasRight: true, onTap: onTap)
                                .frame(width: 260)
                                .id("backlog")
                            ColumnView(id: "in_progress", hasLeft: true, hasRight: true, onTap: onTap)
                                .frame(width: 260)
                                .id("in_progress")
                            ColumnView(id: "review", hasLeft: true, hasRight: true, onTap: onTap)
                                .frame(width: 260)
                                .id("review")
                            ColumnView(id: "done", hasLeft: true, hasRight: false, onTap: onTap)
                                .frame(width: 260)
                                .id("done")
                        }
                        .padding(16)
                    }
                    .frame(height: 280)
                    .accessibilityIdentifier("kanban-scroll")
                }
                .padding(16)
            }
        }

        // Arrange
        let recorder = TapRecorder()
        let tester = ViewTester {
            KanbanLikeView(onTap: { recorder.taps.append($0) })
        }
        .setSize(Size(width: 700, height: 520))
        .performLayout()

        let viewportRect = Rect(origin: .zero, size: Size(width: 700, height: 520))
        let hittableBeforeScroll = tester.collectHitAccessibilityIdentifiers(in: viewportRect)
            .sorted()
            .joined(separator: ", ")

        let scrollPoint = Point(258, 376)
        let scrollWheelHitPath = tester.hitPath(
            at: scrollPoint,
            button: MouseButton.scrollWheel,
            phase: MouseEvent.Phase.changed
        ).joined(separator: " -> ")
        // Act: reveal right-side columns.
        for index in 0..<4 {
            tester.sendMouseEvent(
                at: scrollPoint,
                button: MouseButton.scrollWheel,
                phase: MouseEvent.Phase.changed,
                scrollDelta: Point(-3.2, 0),
                time: Float(index) * 0.01
            )
        }

        let searchRect = Rect(x: 40, y: 140, width: 620, height: 320)
        guard let clickPoint = tester.findHitPoint(
            forAccessibilityIdentifier: "review<",
            in: searchRect,
            step: 2
        ) else {
            let identifiers = tester.collectHitAccessibilityIdentifiers(in: searchRect)
                .sorted()
                .joined(separator: ", ")
            let hittableAfterScroll = tester.collectHitAccessibilityIdentifiers(in: viewportRect)
                .sorted()
                .joined(separator: ", ")
            let probePoints = [Point(60, 200), Point(300, 200), Point(520, 200)]
            let probePaths = probePoints.map { point -> String in
                let path = tester.hitPath(at: point).joined(separator: " -> ")
                return "\(point): \(path)"
            }.joined(separator: "\n")
            let backlogPoint = tester.findHitPoint(
                forAccessibilityIdentifier: "backlog>",
                in: viewportRect,
                step: 2
            )
            let inProgressLeftPoint = tester.findHitPoint(
                forAccessibilityIdentifier: "in_progress<",
                in: viewportRect,
                step: 2
            )
            let inProgressRightPoint = tester.findHitPoint(
                forAccessibilityIdentifier: "in_progress>",
                in: viewportRect,
                step: 2
            )
            let knownNodeFrames = ["backlog>", "in_progress<", "review<", "done<"].map { identifier -> String in
                guard let node = tester.findNodeByAccessibilityIdentifier(identifier) else {
                    return "\(identifier): missing"
                }
                return "\(identifier): frame=\(node.frame) absolute=\(node.absoluteFrame())"
            }.joined(separator: "\n")
            Issue.record("""
            review< is not hittable in searchRect.
            Hittable before scroll: \(hittableBeforeScroll)
            Hittable in searchRect after scroll: \(identifiers)
            Hittable in viewport after scroll: \(hittableAfterScroll)
            backlog> first hittable point: \(String(describing: backlogPoint))
            in_progress< first hittable point: \(String(describing: inProgressLeftPoint))
            in_progress> first hittable point: \(String(describing: inProgressRightPoint))
            Scroll wheel hit path at \(scrollPoint): \(scrollWheelHitPath)
            Known nodes:
            \(knownNodeFrames)
            Probe hit paths:
            \(probePaths)
            """)
            return
        }

        // Assert: click lands exactly on expected button and callback id is correct.
        let targetOnMouseDown = tester.sendMouseEvent(
            at: clickPoint,
            phase: MouseEvent.Phase.began,
            time: 0.02
        )
        tester.sendMouseEvent(
            at: clickPoint,
            phase: MouseEvent.Phase.ended,
            time: 0.03
        )

        #expect(targetOnMouseDown?.accessibilityIdentifier == "review<")
        #expect(recorder.taps.last == "review<")
    }
}
