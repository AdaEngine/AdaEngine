//
//  FlexibleFrameTests.swift
//  AdaEngine
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
import Math

@MainActor
struct FlexibleFrameTests {

    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func frameMinWidthMinHeightExpandMeasuredSize() {
        let tester = ViewTester {
            EmptyView()
                .frame(width: 80, height: 20)
                .frame(minWidth: 100, minHeight: 30)
        }
        .setSize(Size(width: 400, height: 400))
        .performLayout()

        let size = tester.containerView.viewTree.rootNode.contentNode.sizeThatFits(.infinity)
        #expect(size.width == 100)
        #expect(size.height == 30)
    }

    @Test
    func frameMaxWidthClampsMeasuredSize() {
        let tester = ViewTester {
            EmptyView()
                .frame(width: 200, height: 40)
                .frame(maxWidth: 150, maxHeight: 50)
        }
        .setSize(Size(width: 400, height: 400))
        .performLayout()

        let size = tester.containerView.viewTree.rootNode.contentNode.sizeThatFits(.infinity)
        #expect(size.width == 150)
        #expect(size.height == 40)
    }
}
