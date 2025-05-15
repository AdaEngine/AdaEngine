//
//  ViewHitTests.swift
//  AdaEngineTests
//
//  Created by vladislav.prusakov on 09.08.2024.
//

import Testing
@testable import AdaEngine

@MainActor
struct ViewHitTests {
    @Test
    func hitTest_OnBlueButton() {
        // given
        let tester = ViewTester {
            VStack(spacing: 0) {
                Color.red
                    .frame(width: 50, height: 50)
                    .accessibilityIdentifier("Red")

                Color.blue
                    .frame(width: 50, height: 50)
                    .accessibilityIdentifier("Blue")
            }
        }
        .setSize(
            Size(width: 200, height: 200)
        )
        .performLayout()

        // when
        let node = tester.click(at: Point(100, 100)) // click to center of blue
        // then
        #expect(node != nil)
        #expect(tester.findNodeByAccessibilityIdentifier("Blue") === node)
    }
}
