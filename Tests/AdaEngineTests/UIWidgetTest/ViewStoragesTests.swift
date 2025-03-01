//
//  ViewStoragesTests.swift
//
//
//  Created by vladislav.prusakov on 12.08.2024.
//

import XCTest
@testable import AdaEngine

@MainActor
final class ViewStoragesTests: XCTestCase {

    override func setUp() async throws {
        try Application.prepareForTest()
    }

    func test_OnAppearCalled_WhenVisible() {
        // given
        struct TestableView: View {
            @State private var value: String = "Value"

            var body: some View {
                Text(value)
            }
        }

        let tester = ViewTester(rootView: TestableView().accessibilityIdentifier("Test"))
            .setSize(
                Size(width: 400, height: 400)
            )
            .performLayout()

        // when
        let node = tester.findNodeByAccessibilityIdentifier("Test")
        // then
        XCTAssert(node?.storages.count == 1)
        XCTAssert(node?.storages.contains(where: { $0.propertyName == "_value" }) == true, "Incorrect name of property")
        XCTAssert(node?.storages.contains(where: { $0 is StateStorage<String> }) == true, "Incorrect type of stored property")
    }
}
