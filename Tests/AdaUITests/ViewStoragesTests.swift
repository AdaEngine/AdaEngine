//
//  ViewStoragesTests.swift
//
//
//  Created by vladislav.prusakov on 12.08.2024.
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
import AdaInput
import Math

@MainActor
struct ViewStoragesTests {

    init() async throws {
        try Application.prepareForTest()
    }

    // @Test
    // func onAppearCalled_WhenVisible() {
    //     // given
    //     struct TestableView: View {
    //         @State private var value: String = "Value"

    //         var body: some View {
    //             Text(value)
    //         }
    //     }

    //     let tester = ViewTester(rootView: TestableView().accessibilityIdentifier("Test"))
    //         .setSize(
    //             Size(width: 400, height: 400)
    //         )
    //         .performLayout()

    //     // when
    //     let node = tester.findNodeByAccessibilityIdentifier("Test")
    //     // then
    //     #expect(node?.storages.count == 1)
    //     #expect(node?.storages.contains(where: { $0.propertyName == "_value" }) == true, "Incorrect name of property")
    //     #expect(node?.storages.contains(where: { $0 is StateStorage<String> }) == true, "Incorrect type of stored property")
    // }
}
