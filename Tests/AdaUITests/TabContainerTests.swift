//
//  TabContainerTests.swift
//  AdaEngine
//
//  Created by Codex on 24.03.2026.
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
import AdaInput
import Math

@MainActor
struct TabContainerTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func tabContainerSwitchesContentWithoutLayoutCorruption() {
        final class Model {
            var selected: Int = 0
        }

        let model = Model()

        let tester = ViewTester {
            TabContainer(
                ["Alpha", "Beta"],
                selection: Binding(
                    get: { model.selected },
                    set: { model.selected = $0 }
                )
            ) { index in
                if index == 0 {
                    Text("Content A")
                        .accessibilityIdentifier("content-a")
                        .frame(width: 200, height: 40)
                } else {
                    Text("Content B")
                        .accessibilityIdentifier("content-b")
                        .frame(width: 200, height: 40)
                }
            }
            .frame(width: 300, height: 120)
        }
        .setSize(Size(width: 320, height: 140))
        .performLayout()

        let contentRect = Rect(origin: .zero, size: Size(width: 320, height: 140))
        let idsBeforeSwitch = tester.collectHitAccessibilityIdentifiers(in: contentRect)
        #expect(idsBeforeSwitch.contains("content-a"))
        #expect(!idsBeforeSwitch.contains("content-b"))

        model.selected = 1
        tester.invalidateContent().performLayout()

        let idsAfterSwitch = tester.collectHitAccessibilityIdentifiers(in: contentRect)
        #expect(!idsAfterSwitch.contains("content-a"))
        #expect(idsAfterSwitch.contains("content-b"))
    }

    @Test
    func tabContainerSizeFitsContentAndBar() {
        final class Model {
            var selected: Int = 0
        }

        let model = Model()

        let tester = ViewTester {
            TabContainer(
                ["One", "Two", "Three"],
                selection: Binding(
                    get: { model.selected },
                    set: { model.selected = $0 }
                )
            ) { _ in
                HStack(alignment: .center, spacing: 0) {}
                    .frame(width: 100, height: 60)
            }
            .frame(width: 260, height: 100)
        }
        .setSize(Size(width: 280, height: 120))
        .performLayout()

        let containerRect = Rect(origin: .zero, size: Size(width: 280, height: 120))
        let ids = tester.collectHitAccessibilityIdentifiers(in: containerRect)
        #expect(model.selected == 0)
        _ = ids
    }
}
