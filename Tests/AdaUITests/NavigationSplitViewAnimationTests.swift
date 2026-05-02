//
//  NavigationSplitViewAnimationTests.swift
//  AdaEngine
//
//  Created by Codex on 01.05.2026.
//

import Testing
@testable import AdaPlatform
@testable import AdaUI
import AdaUtils
import Math

@MainActor
struct NavigationSplitViewAnimationTests {

    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func animatedColumnVisibilityMovesSidebarInAndOut() {
        let capture = CapturedNavigationSplitVisibility()
        let tester = ViewTester(rootView: AnimatedSidebarSplitView(capture: capture))
            .setSize(Size(width: 720, height: 320))
            .performLayout()

        func sidebarIsHittableNearLeadingEdge() -> Bool {
            tester.findHitPoint(
                forAccessibilityIdentifier: "animated-sidebar",
                in: Rect(x: 1, y: 1, width: 96, height: 96),
                step: 12
            ) != nil
        }

        #expect(sidebarIsHittableNearLeadingEdge())

        capture.visibility.wrappedValue = .detailOnly

        #expect(sidebarIsHittableNearLeadingEdge())

        tester.advanceFrame(deltaTime: 0)
        tester.advanceFrame(deltaTime: 0.5)
        #expect(sidebarIsHittableNearLeadingEdge())

        tester.advanceFrame(deltaTime: 0.5)
        #expect(!sidebarIsHittableNearLeadingEdge())

        capture.visibility.wrappedValue = .all
        tester.advanceFrame(deltaTime: 0)
        tester.advanceFrame(deltaTime: 0.5)
        #expect(sidebarIsHittableNearLeadingEdge())

        tester.advanceFrame(deltaTime: 0.5)
        #expect(sidebarIsHittableNearLeadingEdge())
    }
}

@MainActor
private final class CapturedNavigationSplitVisibility {
    var visibility: Binding<NavigationSplitViewVisibility>!
}

private struct AnimatedSidebarSplitView: View {
    let capture: CapturedNavigationSplitVisibility
    @State private var visibility = NavigationSplitViewVisibility.all

    var body: some View {
        let _ = capture.visibility = $visibility.animation(.linear(duration: 1))

        NavigationSplitView(columnVisibility: $visibility) {
            Color.red
                .onTap { }
                .accessibilityIdentifier("animated-sidebar")
        } detail: {
            Color.blue
                .onTap { }
                .accessibilityIdentifier("animated-detail")
        }
    }
}
