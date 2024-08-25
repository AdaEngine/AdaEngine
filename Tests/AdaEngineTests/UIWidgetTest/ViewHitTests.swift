//
//  ViewHitTests.swift
//  AdaEngineTests
//
//  Created by vladislav.prusakov on 09.08.2024.
//

import XCTest
@testable import AdaEngine

final class ViewHitTests: XCTestCase {
    @MainActor
    func test_HitTest_OnBlueButton() {
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
        XCTAssertNotNil(node, "Hit test failed, we not find a first responder.")
        XCTAssert(tester.findNodeByAccessibilityIdentifier("Blue") === node)
    }
}
