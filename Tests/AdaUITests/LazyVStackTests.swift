//
//  LazyVStackTests.swift
//  AdaEngine
//

import Testing
@testable import AdaPlatform
@testable import AdaUI
import AdaInput
import Math

@MainActor
struct LazyVStackTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func lazyVStackBuildsOnlyVisibleRows() {
        final class BuildCounter {
            var count = 0
        }

        struct LargeList: View {
            let counter: BuildCounter
            let items = Array(0..<10_000)

            var body: some View {
                ScrollView(.vertical) {
                    LazyVStack(items, id: \.self, estimatedRowHeight: 24, overscan: 4) { item in
                        row(item)
                    }
                }
                .frame(width: 120, height: 120)
            }

            private func row(_ item: Int) -> some View {
                counter.count += 1
                return EmptyView()
                    .frame(width: 100, height: 24)
                    .accessibilityIdentifier("row-\(item)")
            }
        }

        let counter = BuildCounter()
        _ = ViewTester {
            LargeList(counter: counter)
        }

        #expect(counter.count < 100)
    }

    @Test
    func lazyVStackUpdatesVisibleRowsWhenScrolled() throws {
        struct LargeList: View {
            let items = Array(0..<1_000)

            var body: some View {
                ScrollView(.vertical) {
                    LazyVStack(items, id: \.self, estimatedRowHeight: 32, overscan: 2) { item in
                        EmptyView()
                            .frame(width: 100, height: 32)
                            .accessibilityIdentifier("row-\(item)")
                    }
                }
                .frame(width: 120, height: 160)
                .accessibilityIdentifier("scroll")
            }
        }

        let tester = ViewTester {
            LargeList()
        }
        .setSize(Size(width: 120, height: 160))
        .performLayout()

        #expect(tester.findNodeByAccessibilityIdentifier("row-0") != nil)
        #expect(tester.findNodeByAccessibilityIdentifier("row-200") == nil)

        let scrollNode = try #require(firstScrollView(in: tester.containerView.viewTree.rootNode))
        scrollNode.scrollToViewNodeIfFoundIt(200, anchor: .top)

        #expect(tester.findNodeByAccessibilityIdentifier("row-200") != nil)
    }

    @Test
    func lazyVStackMeasuredHeightsUpdateContentHeight() {
        struct VariableHeightList: View {
            let items = Array(0..<3)

            var body: some View {
                ScrollView(.vertical) {
                    LazyVStack(items, id: \.self, spacing: 5, estimatedRowHeight: 20, overscan: 2) { item in
                        EmptyView()
                            .frame(width: 100, height: item == 1 ? 80 : 20)
                            .accessibilityIdentifier("row-\(item)")
                    }
                }
                .frame(width: 120, height: 80)
                .accessibilityIdentifier("scroll")
            }
        }

        let tester = ViewTester {
            VariableHeightList()
        }
        .setSize(Size(width: 120, height: 80))
        .performLayout()
        .performLayout()

        let row2 = tester.findNodeById(2)

        #expect(row2?.frame.origin.y == 110)
    }

    @Test
    func scrollToOffscreenLazyRowUsesEstimatedFrameAndBottomAnchor() throws {
        struct LargeList: View {
            let items = Array(0..<500)

            var body: some View {
                ScrollView(.vertical) {
                    LazyVStack(items, id: \.self, spacing: 0, estimatedRowHeight: 40, overscan: 2) { item in
                        EmptyView()
                            .frame(width: 100, height: 40)
                            .accessibilityIdentifier("row-\(item)")
                    }
                }
                .frame(width: 120, height: 160)
                .accessibilityIdentifier("scroll")
            }
        }

        let tester = ViewTester {
            LargeList()
        }
        .setSize(Size(width: 120, height: 160))
        .performLayout()

        let scrollNode = try #require(firstScrollView(in: tester.containerView.viewTree.rootNode))
        scrollNode.scrollToViewNodeIfFoundIt(300, anchor: .bottom)

        #expect(scrollNode.contentOffset.y == 11_880)
        #expect(tester.findNodeByAccessibilityIdentifier("row-300") != nil)
    }
}

@MainActor
private func firstScrollView(in node: ViewNode) -> ScrollViewNode? {
    if let scrollView = node as? ScrollViewNode {
        return scrollView
    }

    if let root = node as? ViewRootNode {
        return firstScrollView(in: root.contentNode)
    }

    if let modifier = node as? ViewModifierNode {
        return firstScrollView(in: modifier.contentNode)
    }

    if let container = node as? ViewContainerNode {
        for child in container.nodes {
            if let scrollView = firstScrollView(in: child) {
                return scrollView
            }
        }
    }

    return nil
}
