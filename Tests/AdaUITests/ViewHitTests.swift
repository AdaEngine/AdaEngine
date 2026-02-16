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
            ScrollableButtonsView(onTap: { recorder.taps.append($0) })
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
}
