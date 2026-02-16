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

        #expect(targetOnMouseDown?.accessibilityIdentifier == "third")
        #expect(recorder.taps.last == "third")
    }

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
